// supabase/functions/validate_content/index.ts
//
// Supabase Edge Function — secure proxy between Flutter app and Anthropic API.
//
// WHY THIS EXISTS:
//   The Flutter app (running on user devices) must NEVER hold the Anthropic API key.
//   This Edge Function runs on Supabase's servers, reads the key from a server-side
//   secret, and forwards validated requests to Anthropic.
//   The Flutter app only calls _supabase.functions.invoke('validate_content', ...).
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
//   Get this from: https://console.anthropic.com/

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const ANTHROPIC_URL  = 'https://api.anthropic.com/v1/messages'
const CLAUDE_MODEL   = 'claude-haiku-4-5-20251001'
const ANTHROPIC_VER  = '2023-06-01'
const MAX_TOKENS_CAP = 2000   // Safety cap — Flutter requests ≤900, but guard anyway

// CORS headers — required so Supabase clients can call this from any origin
const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req: Request) => {
  // CORS preflight — browsers send this before the real POST
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    // ── Read API key from server-side secret (NEVER from client request) ──────
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
    if (!apiKey || !apiKey.startsWith('sk-ant-')) {
      console.error('ANTHROPIC_API_KEY not configured or invalid')
      return new Response(
        JSON.stringify({ error: 'AI validation not configured. Set ANTHROPIC_API_KEY secret.' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // ── Parse request from Flutter app ────────────────────────────────────────
    const body = await req.json() as {
      messages:    unknown[]
      max_tokens?: number
    }

    if (!body.messages || !Array.isArray(body.messages) || body.messages.length === 0) {
      return new Response(JSON.stringify({ error: 'messages array required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Cap max_tokens to prevent abuse
    const maxTokens = Math.min(body.max_tokens ?? 900, MAX_TOKENS_CAP)

    // ── Forward to Anthropic ───────────────────────────────────────────────────
    const anthropicResponse = await fetch(ANTHROPIC_URL, {
      method:  'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         apiKey,      // API key stays server-side, never sent to client
        'anthropic-version': ANTHROPIC_VER,
      },
      body: JSON.stringify({
        model:      CLAUDE_MODEL,         // Model enforced server-side — client cannot override
        max_tokens: maxTokens,
        messages:   body.messages,
      }),
    })

    const data = await anthropicResponse.json()

    if (!anthropicResponse.ok) {
      console.error('Anthropic API error:', anthropicResponse.status, JSON.stringify(data))
      return new Response(JSON.stringify({ error: data }), {
        status: anthropicResponse.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify(data), {
      status:  200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('Edge function error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status:  500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
