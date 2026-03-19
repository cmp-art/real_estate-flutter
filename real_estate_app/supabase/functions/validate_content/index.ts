// supabase/functions/validate_content/index.ts
//
// Supabase Edge Function — secure proxy between Flutter app and Anthropic API.
//
// ENDPOINTS:
//   POST /validate_content          → validate property listing content
//   POST /validate_content/health   → check API key exists + Claude responds
//
// HOW TO DEPLOY:
//   1. Install Supabase CLI: https://supabase.com/docs/guides/cli
//   2. Login: supabase login
//   3. Link project: supabase link --project-ref qeddjlmexurmeiuslgqn
//   4. Set secret: supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-YOUR-KEY-HERE
//   5. Deploy: supabase functions deploy validate_content
//
// ENVIRONMENT VARIABLE (set in Supabase Dashboard → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY = sk-ant-api03-...

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const ANTHROPIC_URL  = 'https://api.anthropic.com/v1/messages'
const CLAUDE_MODEL   = 'claude-haiku-4-5-20251001'
const ANTHROPIC_VER  = '2023-06-01'
const MAX_TOKENS_CAP = 2000

const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// ── Health check: verifies key exists AND Claude actually responds ─────────────
async function handleHealthCheck(apiKey: string): Promise<Response> {
  // Step 1: key format check
  if (!apiKey || !apiKey.startsWith('sk-ant-')) {
    return jsonResponse({
      ok:     false,
      stage:  'key_missing',
      detail: 'ANTHROPIC_API_KEY secret is not set or has wrong format.',
    }, 500)
  }

  // Step 2: live ping to Anthropic — cheapest possible call (1 token)
  try {
    const res = await fetch(ANTHROPIC_URL, {
      method:  'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         apiKey,
        'anthropic-version': ANTHROPIC_VER,
      },
      body: JSON.stringify({
        model:      CLAUDE_MODEL,
        max_tokens: 10,
        messages:   [{ role: 'user', content: 'Reply with the single word: ok' }],
      }),
    })

    const data = await res.json()

    if (!res.ok) {
      // Common causes: invalid key (401), quota exceeded (429), wrong model (404)
      const hint =
        res.status === 401 ? 'API key is invalid or revoked. Generate a new one at console.anthropic.com.' :
        res.status === 429 ? 'Rate limit or quota exceeded. Check your Anthropic plan.' :
        res.status === 404 ? `Model "${CLAUDE_MODEL}" not found. Check model ID.` :
        `Anthropic returned HTTP ${res.status}.`

      return jsonResponse({
        ok:     false,
        stage:  'anthropic_error',
        status: res.status,
        detail: hint,
        raw:    data,
      }, 500)
    }

    // Extract the reply text
    const reply: string = data?.content?.[0]?.text ?? ''

    return jsonResponse({
      ok:       true,
      stage:    'all_good',
      model:    CLAUDE_MODEL,
      reply,              // should be "ok" or similar
      detail:   'API key is valid and Claude is responding correctly.',
    })

  } catch (err) {
    return jsonResponse({
      ok:     false,
      stage:  'network_error',
      detail: `Could not reach Anthropic API: ${String(err)}`,
    }, 500)
  }
}

// ── Main validation handler ────────────────────────────────────────────────────
async function handleValidation(req: Request, apiKey: string): Promise<Response> {
  if (!apiKey || !apiKey.startsWith('sk-ant-')) {
    console.error('ANTHROPIC_API_KEY not configured or invalid')
    return jsonResponse({
      error: 'AI validation not configured. Set ANTHROPIC_API_KEY secret.',
    }, 500)
  }

  const body = await req.json() as {
    messages:    unknown[]
    max_tokens?: number
  }

  if (!body.messages || !Array.isArray(body.messages) || body.messages.length === 0) {
    return jsonResponse({ error: 'messages array required' }, 400)
  }

  const maxTokens = Math.min(body.max_tokens ?? 900, MAX_TOKENS_CAP)

  const anthropicResponse = await fetch(ANTHROPIC_URL, {
    method:  'POST',
    headers: {
      'Content-Type':      'application/json',
      'x-api-key':         apiKey,
      'anthropic-version': ANTHROPIC_VER,
    },
    body: JSON.stringify({
      model:      CLAUDE_MODEL,
      max_tokens: maxTokens,
      messages:   body.messages,
    }),
  })

  const data = await anthropicResponse.json()

  if (!anthropicResponse.ok) {
    console.error('Anthropic API error:', anthropicResponse.status, JSON.stringify(data))
    return jsonResponse({ error: data }, anthropicResponse.status)
  }

  return jsonResponse(data)
}

// ── Entry point ────────────────────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  const apiKey = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
  const url    = new URL(req.url)

  try {
    // Route: POST /validate_content/health
    if (url.pathname.endsWith('/health')) {
      return await handleHealthCheck(apiKey)
    }

    // Route: POST /validate_content  (default)
    return await handleValidation(req, apiKey)

  } catch (err) {
    console.error('Edge function error:', err)
    return jsonResponse({ error: String(err) }, 500)
  }
})
