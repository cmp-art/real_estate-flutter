// supabase/functions/validate_content/index.ts
//
// Gemini content moderation for Patamjengo — runs on EVERY platform
// (Android, iOS, Web, PWA) because it is a plain server-side HTTPS endpoint.
//
// It verifies that:
//   • PROPERTY photos genuinely show real estate — interior rooms, houses,
//     apartments, commercial/business premises, or land/plots — and NOT
//     people, food, vehicles, documents, screenshots, etc.
//   • AD images contain no sexual or violent content (all other legitimate
//     business categories are allowed).
//
// The Gemini API key NEVER reaches the client — it lives only here as the
// GEMINI_API_KEY Edge Function secret.
//
// ── Request (POST, JSON) ─────────────────────────────────────────────────────
//   {
//     "contentType": "property" | "ad",
//     "images": [ { "data": "<base64>", "mimeType": "image/jpeg" }, ... ]
//   }
//
// ── Response (always HTTP 200 so the client can branch, never hard-fails) ─────
//   { "ok": true,  "stage": "ai", "approved": bool, "category": str,
//     "confidence": int, "reason": str }
//   { "ok": false, "stage": "not_configured" | "bad_request" | "gemini_error",
//     "detail": str }
//   On any ok:false the Flutter client falls back to its rule-based text check,
//   so submissions keep working even before this function is deployed.
//
// ── Deploy ────────────────────────────────────────────────────────────────────
//   supabase secrets set GEMINI_API_KEY=<your key from aistudio.google.com>
//   supabase functions deploy validate_content --no-verify-jwt
// Optional: override the model with
//   supabase secrets set GEMINI_MODEL=gemini-2.0-flash-lite

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

const MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.0-flash-lite'
const MAX_IMAGES = 6

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

const PROPERTY_PROMPT = `You are a strict content moderator for a real-estate marketplace.
You are shown one or more photos a user wants to attach to a PROPERTY LISTING.

APPROVE (approved=true) only if EVERY photo plausibly depicts real estate or
directly related content: interior rooms (bedroom, living room, kitchen,
bathroom, hallway), building exteriors, whole houses or apartments,
commercial / office / shop / business premises, or land / plots / farm parcels
(including mostly-empty land with grass, soil, fences or boundary markers).

REJECT (approved=false) if ANY photo's main subject is NOT real estate, e.g.:
people or selfies, food or drink, vehicles, animals or pets, electronics or
other products, clothing, documents or ID cards, screenshots of apps or chats,
memes, or images that are mostly text.

ALWAYS REJECT sexual, nude, sexually-suggestive, violent or gory content.

Respond with: approved (boolean), category (a short label for the dominant
subject, e.g. "bedroom","house exterior","land","vehicle","food","person",
"document","screenshot","sexual","violent"), confidence (integer 0-100), and
reason (one short user-facing sentence).`

const AD_PROMPT = `You are a content-SAFETY moderator for advertising images on a
real-estate app. Advertisements from ANY legitimate business category are
allowed (retail, food, technology, services, property, automotive, health,
education, etc.). Your ONLY job is to block UNSAFE imagery.

REJECT (approved=false) ONLY if the image contains sexual, nude or
sexually-suggestive content, OR violent, gory, graphic-injury or weapon-threat
content.

APPROVE (approved=true) everything else, including ordinary product photos,
company logos, text or graphic banners, and people in non-sexual contexts.

Respond with: approved (boolean), category (e.g. "safe","sexual","violent"),
confidence (integer 0-100), reason (one short user-facing sentence).`

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY')

  // Health check / readiness probe.
  if (req.method === 'GET') {
    return json({
      ok: !!apiKey,
      stage: apiKey ? 'all_good' : 'not_configured',
      model: MODEL,
      detail: apiKey
        ? 'Gemini moderation is ready.'
        : 'GEMINI_API_KEY secret is not set on this function.',
    })
  }

  if (!apiKey) {
    return json({
      ok: false,
      stage: 'not_configured',
      detail: 'GEMINI_API_KEY secret is not set on this function.',
    })
  }

  // Parse + sanitise input.
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch (_) {
    return json({ ok: false, stage: 'bad_request', detail: 'Invalid JSON body.' })
  }

  const contentType = body?.contentType === 'ad' ? 'ad' : 'property'
  const rawImages = Array.isArray(body?.images) ? body.images : []
  const images = (rawImages as Array<Record<string, unknown>>)
    .filter((im) => im && typeof im.data === 'string' && (im.data as string).length > 0)
    .slice(0, MAX_IMAGES)
    .map((im) => ({
      mimeType: typeof im.mimeType === 'string' ? (im.mimeType as string) : 'image/jpeg',
      data: im.data as string,
    }))

  if (images.length === 0) {
    return json({ ok: false, stage: 'bad_request', detail: 'No images supplied.' })
  }

  const prompt = contentType === 'ad' ? AD_PROMPT : PROPERTY_PROMPT

  const parts: unknown[] = [{ text: prompt }]
  for (const im of images) {
    parts.push({ inline_data: { mime_type: im.mimeType, data: im.data } })
  }

  const geminiRequest = {
    contents: [{ role: 'user', parts }],
    generationConfig: {
      temperature: 0,
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        properties: {
          approved: { type: 'BOOLEAN' },
          category: { type: 'STRING' },
          confidence: { type: 'INTEGER' },
          reason: { type: 'STRING' },
        },
        required: ['approved', 'category', 'confidence', 'reason'],
      },
    },
    // BLOCK_NONE so Gemini RETURNS a verdict on unsafe images instead of
    // refusing — we want it to classify the content, not silently drop it.
    safetySettings: [
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
    ],
  }

  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${apiKey}`

  let resp: Response
  try {
    resp = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiRequest),
    })
  } catch (e) {
    return json({ ok: false, stage: 'gemini_error', detail: `fetch failed: ${e}` })
  }

  if (!resp.ok) {
    const text = await resp.text().catch(() => '')
    return json({
      ok: false,
      stage: 'gemini_error',
      detail: `Gemini HTTP ${resp.status}: ${text.slice(0, 300)}`,
    })
  }

  let payload: Record<string, unknown>
  try {
    payload = await resp.json()
  } catch (e) {
    return json({ ok: false, stage: 'gemini_error', detail: `bad response JSON: ${e}` })
  }

  // deno-lint-ignore no-explicit-any
  const candidates = (payload as any)?.candidates
  const textOut: string | undefined = candidates?.[0]?.content?.parts?.[0]?.text
  if (!textOut) {
    const finish = candidates?.[0]?.finishReason ?? 'unknown'
    return json({
      ok: false,
      stage: 'gemini_error',
      detail: `Gemini returned no content (finishReason=${finish}).`,
    })
  }

  // deno-lint-ignore no-explicit-any
  let verdict: any
  try {
    verdict = JSON.parse(textOut)
  } catch (_) {
    return json({
      ok: false,
      stage: 'gemini_error',
      detail: 'Model did not return valid JSON.',
    })
  }

  const approved = verdict?.approved === true
  let confidence = Number(verdict?.confidence)
  if (!Number.isFinite(confidence)) confidence = approved ? 80 : 70
  confidence = Math.max(0, Math.min(100, Math.round(confidence)))

  return json({
    ok: true,
    stage: 'ai',
    approved,
    category: typeof verdict?.category === 'string' ? verdict.category : '',
    confidence,
    reason: typeof verdict?.reason === 'string' ? verdict.reason : '',
  })
})
