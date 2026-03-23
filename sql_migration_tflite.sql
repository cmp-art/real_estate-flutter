-- ============================================================================
-- MIGRATION: Switch AI validation from Claude Haiku → MobileNet V3 TFLite
-- Run this once in Supabase SQL Editor.
-- ============================================================================

-- 1. Remove the Claude API key config entry (no longer used)
DELETE FROM app_config WHERE key = 'claude_api_key';

-- 2. Update the AI validation description to reflect TFLite
UPDATE app_config
SET    description = 'Master switch: set to false to disable on-device TFLite validation and use rule-based fallback only'
WHERE  key = 'ai_validation_enabled';

-- 3. Add TFLite model config entry (informational — model runs on-device)
INSERT INTO app_config (key, value, description)
VALUES (
    'tflite_model',
    'mobilenet_v3_small_100_224',
    'On-device image classification model bundled with the app. No API key required.'
)
ON CONFLICT (key) DO UPDATE
    SET value       = EXCLUDED.value,
        description = EXCLUDED.description;

-- 4. Update table comment
COMMENT ON TABLE app_config IS
    'Runtime admin configuration. AI image validation uses on-device MobileNet V3 TFLite — no API key needed.';

-- 5. Verify
SELECT key, value, description FROM app_config ORDER BY key;
