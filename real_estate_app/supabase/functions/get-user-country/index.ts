// supabase/functions/get-user-country/index.ts
//
// Supabase Edge Function — returns the calling user's country via Cloudflare's
// CF-IPCountry header. This header is injected by Cloudflare at the network
// level and CANNOT be spoofed by the client — it reflects the true source IP.
//
// HOW TO DEPLOY:
//   1. Install Supabase CLI: https://supabase.com/docs/guides/cli
//   2. Login:               supabase login
//   3. Link project:        supabase link --project-ref qeddjlmexurmeiuslgqn
//   4. Deploy:              supabase functions deploy get-user-country --no-verify-jwt
//
// RESPONSE:
//   { "country": "TZ" }   — ISO 3166-1 alpha-2 code
//   { "country": "XX" }   — Cloudflare could not determine country (local dev / VPN)
//
// USED BY:
//   lib/core/providers/ip_country_provider.dart → feeds ad targeting + property default filter

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Cloudflare injects CF-IPCountry before the request reaches this function.
  // Falls back to 'XX' (unknown) in local dev or when Cloudflare can't resolve.
  const country = req.headers.get('cf-ipcountry') ?? 'XX'

  return new Response(
    JSON.stringify({ country }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    },
  )
})
