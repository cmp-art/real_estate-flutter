// supabase/functions/validate_content/index.ts
//
// DEPRECATED — No longer used for AI validation.
//
// AI image validation has moved fully on-device using MobileNet V3 TFLite.
// Text validation uses rule-based keyword scoring in the Flutter app.
// No Anthropic API key or cloud AI call is needed.
//
// This function is kept as a stub so existing deploys don't 404.
// You may safely delete it from Supabase if you prefer.
//
// To delete:
//   supabase functions delete validate_content

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const url = new URL(req.url)

  // Health check endpoint — always returns ok (no Claude dependency)
  if (url.pathname.endsWith('/health') || req.method === 'GET') {
    return jsonResponse({
      ok:     true,
      stage:  'deprecated',
      model:  'mobilenet_v3_tflite',
      detail: 'AI validation has moved on-device. This Edge Function is no longer used.',
    })
  }

  // Any POST — return deprecation notice (Flutter app no longer calls this)
  return jsonResponse({
    ok:     false,
    stage:  'deprecated',
    detail: 'This endpoint is deprecated. AI validation now runs on-device via MobileNet V3 TFLite.',
  }, 410) // 410 Gone
})
