// supabase/functions/send-push-notification/index.ts
//
// Sends FCM push notifications for a user_notifications row.
// FCM is free — no cost per message, no limits.
//
// Uses FCM HTTP v1 API with a service account JWT (no npm packages, pure Deno crypto).
//
// CALLING MODES — this function accepts TWO call styles:
//
//   1. Direct call from the Flutter app (NotificationService._sendPushNotification):
//        POST body: { user_id, id, type, title, message, data }
//        No Database Webhook needed — the app calls this right after INSERT.
//
//   2. Supabase Database Webhook (legacy / optional):
//        POST body: { type: "INSERT", record: { user_id, id, type, title, message, data } }
//        Works automatically because of: const record = payload.record ?? payload
//
// Required Supabase secrets (Dashboard → Settings → Edge Functions → Secrets):
//   FIREBASE_SERVICE_ACCOUNT  — full service account JSON (copy from Firebase Console
//                               → Project Settings → Service accounts → Generate new key)
//
// Deploy:
//   supabase functions deploy send-push-notification --no-verify-jwt

import { serve }       from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// ── Service account types ─────────────────────────────────────────────────────
interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// ── Convert PEM private key to CryptoKey ──────────────────────────────────────
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');

  const binaryDer = atob(pemContents);
  const derBuffer = new Uint8Array(binaryDer.length);
  for (let i = 0; i < binaryDer.length; i++) {
    derBuffer[i] = binaryDer.charCodeAt(i);
  }

  return crypto.subtle.importKey(
    'pkcs8',
    derBuffer.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

// ── Base64url encode a string or Uint8Array ───────────────────────────────────
function base64url(input: string | Uint8Array): string {
  const str = typeof input === 'string' ? input : String.fromCharCode(...input);
  return btoa(str).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

// ── Build and sign a JWT for Google OAuth2 ───────────────────────────────────
async function buildJwt(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header  = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64url(JSON.stringify({
    iss:   sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud:   'https://oauth2.googleapis.com/token',
    iat:   now,
    exp:   now + 3600,
  }));

  const signingInput = `${header}.${payload}`;
  const key          = await importPrivateKey(sa.private_key);
  const signatureRaw = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );

  const sig = base64url(new Uint8Array(signatureRaw));
  return `${signingInput}.${sig}`;
}

// ── Exchange JWT for a short-lived Google access token ───────────────────────
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const jwt = await buildJwt(sa);

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion:  jwt,
    }),
  });

  const data = await resp.json();
  if (!data.access_token) {
    throw new Error(`OAuth2 token exchange failed: ${JSON.stringify(data)}`);
  }
  return data.access_token as string;
}

// ── Send one FCM message via HTTP v1 API ─────────────────────────────────────
async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ status: number; body: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        // 'notification' field → OS shows the banner automatically on Android
        // and iOS even when the app is killed (no Dart background handler needed)
        notification: { title, body },
        // 'data' field → available in the app after tap (all strings required)
        data,
        android: {
          priority: 'high',
          // channel_id must match the high-importance channel the app creates at
          // startup + the manifest default_notification_channel_id, so background
          // banners show as heads-up instead of on a low-importance fallback.
          notification: {
            sound: 'default',
            channel_id: 'patamjengo_main',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: { aps: { sound: 'default', 'content-available': 1 } },
        },
        webpush: {
          headers: { TTL: '86400' },
          notification: {
            icon:  '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
          },
        },
      },
    }),
  });

  return { status: resp.status, body: await resp.text() };
}

// ── Main handler ─────────────────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Parse Supabase webhook payload ──────────────────────────────────────
    const payload = await req.json();
    const record  = payload.record ?? payload; // webhook wraps in { type, record }

    const userId: string | undefined = record.user_id;
    const title:  string = record.title   ?? 'Patamjengo';
    const body:   string = record.message ?? 'You have a new notification.';
    const notifType: string = record.type ?? 'general';
    const notifData: Record<string, unknown> = record.data ?? {};
    const notifId:   string = record.id  ?? '';

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'No user_id in webhook payload' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Parse Firebase service account ──────────────────────────────────────
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '';
    if (!saJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT secret is not set');
    }
    const sa: ServiceAccount = JSON.parse(saJson);

    // ── Init Supabase admin client ───────────────────────────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // ── Get active FCM tokens for this user ─────────────────────────────────
    const { data: tokens, error: fetchError } = await supabase
      .from('device_push_tokens')
      .select('id, token, platform')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (fetchError) throw fetchError;

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No active push tokens for user' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Get OAuth2 access token (single request covers all FCM sends) ────────
    const accessToken = await getAccessToken(sa);

    // ── FCM data payload — all values must be strings ────────────────────────
    const dataPayload: Record<string, string> = {
      type:            notifType,
      notification_id: notifId,
    };
    // Convert notifData values to strings (FCM requirement)
    for (const [k, v] of Object.entries(notifData)) {
      if (v !== null && v !== undefined) {
        dataPayload[k] = String(v);
      }
    }
    if (dataPayload.property_id) {
      dataPayload.url = `/property/${dataPayload.property_id}`;
    }

    // ── Send to each registered device/browser ───────────────────────────────
    let sent = 0, failed = 0;

    await Promise.allSettled(
      tokens.map(async (t: { id: string; token: string; platform: string }) => {
        const result = await sendFcmMessage(
          accessToken, sa.project_id, t.token, title, body, dataPayload,
        );

        if (result.status === 200) {
          sent++;
        } else {
          failed++;
          console.warn(`[FCM] Failed (${result.status}) for ${t.platform}: ${result.body}`);

          // 404 = token not registered; 410 = token expired → deactivate
          if (result.status === 404 || result.status === 410) {
            await supabase
              .from('device_push_tokens')
              .update({ is_active: false })
              .eq('id', t.id);
            console.log(`[FCM] Deactivated stale token ${t.id} (${t.platform})`);
          }
        }
      }),
    );

    console.log(`[FCM] user=${userId} sent=${sent} failed=${failed}`);

    return new Response(
      JSON.stringify({ sent, failed, user_id: userId }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[FCM] Error:', message);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
