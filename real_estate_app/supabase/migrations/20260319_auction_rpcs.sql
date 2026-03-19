-- ============================================================
-- PATAMJENGO AD AUCTION — SUPABASE SQL MIGRATIONS
-- Run this entire file in Supabase → SQL Editor
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. get_eligible_ads
--    Called by the app to fetch ads for a screen.
--    AUCTION: orders by bid_amount DESC — highest bidder wins.
--    Enforces: budget caps, date range, approval, daily limit,
--              targeting (location + property type), active status.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_eligible_ads(
  p_user_id            UUID,
  p_screen_name        TEXT,
  p_property_id        UUID    DEFAULT NULL,
  p_limit              INT     DEFAULT 5,
  p_user_region        TEXT    DEFAULT NULL,
  p_user_property_type TEXT    DEFAULT NULL
)
RETURNS TABLE (
  campaign_id        UUID,
  creative_id        UUID,
  advertiser_id      UUID,
  advertiser_user_id UUID,
  headline           TEXT,
  description        TEXT,
  call_to_action     TEXT,
  image_url          TEXT,
  logo_url           TEXT,
  landing_url        TEXT,
  bid_amount         NUMERIC,
  bidding_strategy   TEXT,
  media_type         TEXT,
  video_url          TEXT,
  destination_type   TEXT,
  linked_property_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id                  AS campaign_id,
    cr.id                 AS creative_id,
    c.advertiser_id,
    a.user_id             AS advertiser_user_id,
    cr.headline,
    cr.description,
    cr.call_to_action,
    cr.image_url,
    cr.logo_url,
    cr.landing_url,
    c.bid_amount,
    c.bidding_strategy,
    cr.media_type,
    cr.video_url,
    cr.destination_type,
    cr.linked_property_id
  FROM   ad_campaigns c
  JOIN   ad_creatives cr ON cr.campaign_id = c.id
  JOIN   advertisers  a  ON a.id = c.advertiser_id
  WHERE
    -- Campaign must be running
    c.status = 'running'
    AND c.deleted_at IS NULL

    -- Creative must be active and approved
    AND cr.status    = 'active'
    AND cr.is_approved = TRUE
    AND cr.deleted_at IS NULL

    -- Campaign must be within its scheduled dates
    AND c.start_date <= NOW()
    AND c.end_date   >= NOW()

    -- Total budget not exhausted
    AND c.spent_amount < c.total_budget

    -- Advertiser must be active with positive balance
    AND a.status          = 'active'
    AND a.account_balance > 0

    -- Never show a user their own ads
    AND a.user_id != p_user_id

    -- Daily budget cap: sum of today's costs must be below daily_budget
    AND (
      SELECT COALESCE(SUM(i.cost), 0)
      FROM   ad_impressions i
      WHERE  i.campaign_id = c.id
        AND  i.created_at >= CURRENT_DATE
    ) < c.daily_budget

    -- Location targeting: empty array = all Tanzania (no filter)
    AND (
      array_length(c.target_locations, 1) IS NULL
      OR cardinality(c.target_locations) = 0
      OR p_user_region IS NULL
      OR p_user_region = ANY(c.target_locations)
    )

    -- Property-type targeting: empty = all types (no filter)
    AND (
      array_length(c.target_property_types, 1) IS NULL
      OR cardinality(c.target_property_types) = 0
      OR p_user_property_type IS NULL
      OR p_user_property_type = ANY(c.target_property_types)
    )

  -- AUCTION CORE: highest bid wins the slot
  ORDER BY c.bid_amount DESC

  LIMIT p_limit;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 2. record_ad_impression
--    Records one impression and deducts CPM cost from balance.
--    CPC campaigns: cost = 0 (deducted only on click).
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION record_ad_impression(
  p_campaign_id   UUID,
  p_creative_id   UUID,
  p_advertiser_id UUID,
  p_user_id       UUID,
  p_screen_name   TEXT,
  p_property_id   UUID    DEFAULT NULL,
  p_cost          NUMERIC DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_impression_id UUID;
BEGIN
  -- Insert impression record
  INSERT INTO ad_impressions (
    campaign_id, creative_id, advertiser_id, user_id,
    screen_name, property_id, cost
  ) VALUES (
    p_campaign_id, p_creative_id, p_advertiser_id, p_user_id,
    p_screen_name, p_property_id, p_cost
  )
  RETURNING id INTO v_impression_id;

  -- Increment campaign counters
  UPDATE ad_campaigns SET
    impressions_count = impressions_count + 1,
    spent_amount      = spent_amount + p_cost,
    updated_at        = NOW()
  WHERE id = p_campaign_id;

  -- Increment creative counter
  UPDATE ad_creatives SET
    impressions = impressions + 1,
    updated_at  = NOW()
  WHERE id = p_creative_id;

  -- Deduct from advertiser balance (CPM only; CPC cost=0 here)
  IF p_cost > 0 THEN
    UPDATE advertisers SET
      account_balance = account_balance - p_cost,
      total_spent     = total_spent + p_cost,
      updated_at      = NOW()
    WHERE id = p_advertiser_id;
  END IF;

  RETURN v_impression_id;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 3. record_ad_click
--    Records a click and deducts CPC cost from balance.
--    Fraud guard: >3 clicks/day by same user on same campaign
--    → cost forced to 0 (click still counted for CTR).
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION record_ad_click(
  p_impression_id UUID,
  p_campaign_id   UUID,
  p_creative_id   UUID,
  p_advertiser_id UUID,
  p_user_id       UUID,
  p_cost          NUMERIC DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_click_id     UUID;
  v_daily_clicks INT;
  v_actual_cost  NUMERIC := p_cost;
BEGIN
  -- Fraud check: same user clicking same campaign >3×/day pays nothing
  SELECT COUNT(*) INTO v_daily_clicks
  FROM   ad_clicks
  WHERE  campaign_id = p_campaign_id
    AND  user_id     = p_user_id
    AND  created_at >= CURRENT_DATE;

  IF v_daily_clicks >= 3 THEN
    v_actual_cost := 0;
  END IF;

  -- Insert click record
  INSERT INTO ad_clicks (
    impression_id, campaign_id, creative_id,
    advertiser_id, user_id, cost
  ) VALUES (
    p_impression_id, p_campaign_id, p_creative_id,
    p_advertiser_id, p_user_id, v_actual_cost
  )
  RETURNING id INTO v_click_id;

  -- Update campaign counters + recalculate CTR
  UPDATE ad_campaigns SET
    clicks_count = clicks_count + 1,
    spent_amount = spent_amount + v_actual_cost,
    ctr = CASE
            WHEN impressions_count > 0
            THEN (clicks_count + 1)::NUMERIC / impressions_count * 100
            ELSE 0
          END,
    updated_at   = NOW()
  WHERE id = p_campaign_id;

  -- Update creative click counter
  UPDATE ad_creatives SET
    clicks     = clicks + 1,
    updated_at = NOW()
  WHERE id = p_creative_id;

  -- Deduct from advertiser balance (CPC campaigns only)
  IF v_actual_cost > 0 THEN
    UPDATE advertisers SET
      account_balance = account_balance - v_actual_cost,
      total_spent     = total_spent + v_actual_cost,
      updated_at      = NOW()
    WHERE id = p_advertiser_id;
  END IF;

  RETURN v_click_id;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 4. process_advertiser_payment
--    Adds funds to advertiser balance (additive, idempotent).
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION process_advertiser_payment(
  p_advertiser_id     UUID,
  p_amount            NUMERIC,
  p_transaction_id    TEXT,
  p_payment_method    TEXT,
  p_provider_reference TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Guard: don't process the same transaction twice
  IF EXISTS (
    SELECT 1 FROM advertiser_payments
    WHERE transaction_id = p_transaction_id AND status = 'completed'
  ) THEN
    RETURN;
  END IF;

  -- Credit the advertiser's balance
  UPDATE advertisers SET
    account_balance = account_balance + p_amount,
    updated_at      = NOW()
  WHERE id = p_advertiser_id;

  -- Record the payment
  INSERT INTO advertiser_payments (
    advertiser_id, amount, currency, payment_method,
    transaction_id, payment_provider, provider_reference,
    status, payment_date, completed_at
  ) VALUES (
    p_advertiser_id, p_amount, 'TZS', p_payment_method,
    p_transaction_id, 'selcom', p_provider_reference,
    'completed', NOW(), NOW()
  )
  ON CONFLICT (transaction_id) DO NOTHING;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 5. verify_and_complete_payment
--    Background reconciliation — safe to call multiple times.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION verify_and_complete_payment(
  p_transaction_id     TEXT,
  p_provider_reference TEXT,
  p_amount             NUMERIC,
  p_advertiser_id      UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Already completed — idempotent
  IF EXISTS (
    SELECT 1 FROM advertiser_payments
    WHERE transaction_id = p_transaction_id AND status = 'completed'
  ) THEN
    RETURN json_build_object('success', true, 'message', 'already_completed');
  END IF;

  -- Credit and record
  PERFORM process_advertiser_payment(
    p_advertiser_id,
    p_amount,
    p_transaction_id,
    'mobile_money',
    p_provider_reference
  );

  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ────────────────────────────────────────────────────────────
-- Required tables (run only if they don't exist yet)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ad_impressions (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id    UUID        NOT NULL REFERENCES ad_campaigns(id),
  creative_id    UUID        NOT NULL REFERENCES ad_creatives(id),
  advertiser_id  UUID        NOT NULL REFERENCES advertisers(id),
  user_id        UUID        NOT NULL,
  screen_name    TEXT        NOT NULL,
  property_id    UUID,
  cost           NUMERIC     NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ad_clicks (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  impression_id  UUID        NOT NULL REFERENCES ad_impressions(id),
  campaign_id    UUID        NOT NULL REFERENCES ad_campaigns(id),
  creative_id    UUID        NOT NULL REFERENCES ad_creatives(id),
  advertiser_id  UUID        NOT NULL REFERENCES advertisers(id),
  user_id        UUID        NOT NULL,
  cost           NUMERIC     NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast daily budget lookups
CREATE INDEX IF NOT EXISTS idx_ad_impressions_campaign_date
  ON ad_impressions (campaign_id, created_at);

CREATE INDEX IF NOT EXISTS idx_ad_clicks_campaign_user_date
  ON ad_clicks (campaign_id, user_id, created_at);
