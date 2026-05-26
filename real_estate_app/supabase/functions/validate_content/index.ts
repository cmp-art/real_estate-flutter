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
// ── Model ─────────────────────────────────────────────────────────────────────
//   Primary model: gemini-3.1-flash-lite. If a key/region can't use it, the
//   function automatically falls back to 2.5-flash-lite then 2.0-flash-lite, and
//   caches the first one that works. Override the whole chain with the
//   GEMINI_MODEL secret (then ONLY that model is used).
//   Request format is kept version-portable: responseMimeType=application/json
//   (no strict responseSchema, whose field name changed in Gemini 3) + a strict
//   prompt + lenient JSON parsing; temperature is left at the model default
//   (Gemini 3 recommends not lowering it).
//
// ── Request (POST, JSON) ─────────────────────────────────────────────────────
//   {
//     "contentType": "property" | "ad",
//     "images": [ { "data": "<base64>", "mimeType": "image/jpeg" }, ... ]
//   }
//
// ── Response (always HTTP 200 so the client can branch, never hard-fails) ─────
//   { "ok": true,  "stage": "ai", "approved": bool, "category": str,
//     "confidence": int, "reason": str, "model": str }
//   { "ok": false, "stage": "not_configured" | "bad_request" | "gemini_error",
//     "detail": str }
//   On any ok:false the Flutter client allows the submission through (it never
//   judges by text), so uploads keep working even before this is deployed.
//
//   GET this function (health check) to see exactly which models YOUR key can
//   use and which one would be picked — handy for diagnosing "not working".
//
// ── Deploy ────────────────────────────────────────────────────────────────────
//   supabase secrets set GEMINI_API_KEY=<your key from aistudio.google.com>
//   supabase functions deploy validate_content --no-verify-jwt
//   (Optional) pin the model:  supabase secrets set GEMINI_MODEL=gemini-3.1-flash-lite

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

const ENV_MODEL = Deno.env.get('GEMINI_MODEL')?.trim()
// Newest first. If GEMINI_MODEL is set, ONLY that model is tried.
const MODEL_CANDIDATES = ENV_MODEL && ENV_MODEL.length > 0
  ? [ENV_MODEL]
  : ['gemini-3.1-flash-lite', 'gemini-2.5-flash-lite', 'gemini-2.0-flash-lite']

// Cached across warm invocations so we don't re-probe unavailable models.
let resolvedModel: string | null = null

const MAX_IMAGES = 6
const API_BASE = 'https://generativelanguage.googleapis.com/v1beta'

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

ALWAYS REJECT sexual, nude, sexually-suggestive, violent or gory content.`

const AD_PROMPT = `You are a content-SAFETY moderator for advertising images on a
real-estate app. Advertisements from ANY legitimate business category are
allowed (retail, food, technology, services, property, automotive, health,
education, etc.). Your ONLY job is to block UNSAFE imagery.

REJECT (approved=false) ONLY if the image contains sexual, nude or
sexually-suggestive content, OR violent, gory, graphic-injury or weapon-threat
content.

APPROVE (approved=true) everything else, including ordinary product photos,
company logos, text or graphic banners, and people in non-sexual contexts.`

const OUTPUT_RULES = `

Respond with ONLY a single JSON object — no markdown, no code fences, no extra
text — with EXACTLY these keys:
{"approved": boolean, "category": string, "confidence": integer 0-100, "reason": string}
"category" is a short label for the dominant subject (e.g. "bedroom","house
exterior","land","vehicle","food","person","document","screenshot","sexual",
"violent","safe"). "reason" is one short user-facing sentence.`

// Standard v1beta safety settings — ask Gemini to RETURN a verdict on unsafe
// images instead of refusing, so we can classify them ourselves.
const SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
]

// deno-lint-ignore no-explicit-any
function buildRequest(prompt: string, images: Array<{ mimeType: string; data: string }>): any {
  // deno-lint-ignore no-explicit-any
  const parts: any[] = [{ text: prompt }]
  for (const im of images) {
    parts.push({ inlineData: { mimeType: im.mimeType, data: im.data } })
  }
  return {
    contents: [{ role: 'user', parts }],
    generationConfig: { responseMimeType: 'application/json' },
    safetySettings: SAFETY_SETTINGS,
  }
}

// Try each candidate model until one succeeds (or a non-model error occurs).
// deno-lint-ignore no-explicit-any
async function generateWithFallback(
  apiKey: string,
  // deno-lint-ignore no-explicit-any
  body: any,
): Promise<{ model: string; payload: Record<string, unknown> } | { error: string }> {
  const order = resolvedModel
    ? [resolvedModel, ...MODEL_CANDIDATES.filter((m) => m !== resolvedModel)]
    : [...MODEL_CANDIDATES]

  let lastDetail = 'no models tried'
  for (const model of order) {
    let resp: Response
    try {
      resp = await fetch(`${API_BASE}/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
    } catch (e) {
      lastDetail = `fetch failed for ${model}: ${e}`
      continue
    }

    if (resp.ok) {
      resolvedModel = model
      try {
        return { model, payload: await resp.json() }
      } catch (e) {
        return { error: `bad response JSON from ${model}: ${e}` }
      }
    }

    const text = await resp.text().catch(() => '')
    lastDetail = `HTTP ${resp.status} for ${model}: ${text.slice(0, 220)}`
    // Only switching models helps when the MODEL is the problem.
    const modelProblem =
      resp.status === 404 ||
      /not found|not_found|is not supported|does not exist|unsupported/i.test(text)
    if (modelProblem) continue
    // 400/403/429/5xx won't be fixed by another model — surface it.
    return { error: lastDetail }
  }
  return { error: `no usable model — ${lastDetail}` }
}

// Pull the answer text out of the response (concatenate all text parts so a
// thinking/answer split in Gemini 3 doesn't drop the JSON).
function extractText(payload: Record<string, unknown>): string {
  // deno-lint-ignore no-explicit-any
  const cand = (payload as any)?.candidates?.[0]
  // deno-lint-ignore no-explicit-any
  const parts = cand?.content?.parts
  if (!Array.isArray(parts)) return ''
  // deno-lint-ignore no-explicit-any
  return parts.map((p: any) => (typeof p?.text === 'string' ? p.text : '')).join('').trim()
}

function parseVerdict(text: string):
  | { approved: boolean; category: string; confidence: number; reason: string }
  | null {
  let t = text.trim()
  const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fence) t = fence[1].trim()
  const start = t.indexOf('{')
  const end = t.lastIndexOf('}')
  if (start >= 0 && end > start) t = t.slice(start, end + 1)
  try {
    // deno-lint-ignore no-explicit-any
    const v: any = JSON.parse(t)
    const approved = v.approved === true
    let confidence = Number(v.confidence)
    if (!Number.isFinite(confidence)) confidence = approved ? 80 : 70
    confidence = Math.max(0, Math.min(100, Math.round(confidence)))
    return {
      approved,
      category: typeof v.category === 'string' ? v.category : '',
      confidence,
      reason: typeof v.reason === 'string' ? v.reason : '',
    }
  } catch (_) {
    return null
  }
}

// Health check: list the generateContent-capable models the key can use.
async function healthCheck(apiKey: string): Promise<Response> {
  let resp: Response
  try {
    resp = await fetch(`${API_BASE}/models?key=${apiKey}&pageSize=1000`)
  } catch (e) {
    return json({ ok: false, stage: 'gemini_error', detail: `fetch failed: ${e}` })
  }
  if (!resp.ok) {
    const text = await resp.text().catch(() => '')
    return json({
      ok: false,
      stage: 'gemini_error',
      detail: `ListModels HTTP ${resp.status}: ${text.slice(0, 220)}`,
    })
  }
  // deno-lint-ignore no-explicit-any
  const data: any = await resp.json().catch(() => ({}))
  const available: string[] = Array.isArray(data?.models)
    ? data.models
        // deno-lint-ignore no-explicit-any
        .filter((m: any) => (m?.supportedGenerationMethods ?? []).includes('generateContent'))
        // deno-lint-ignore no-explicit-any
        .map((m: any) => String(m?.name ?? '').replace(/^models\//, ''))
    : []
  const picked = MODEL_CANDIDATES.find((m) => available.includes(m)) ??
    available.find((m) => m.includes('flash-lite')) ??
    available.find((m) => m.includes('flash')) ??
    available[0] ??
    null
  return json({
    ok: picked != null,
    stage: picked != null ? 'all_good' : 'no_model',
    preferredChain: MODEL_CANDIDATES,
    picked,
    availableCount: available.length,
    available,
  })
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY')

  if (req.method === 'GET') {
    if (!apiKey) {
      return json({
        ok: false,
        stage: 'not_configured',
        detail: 'GEMINI_API_KEY secret is not set on this function.',
        preferredChain: MODEL_CANDIDATES,
      })
    }
    return await healthCheck(apiKey)
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

  const prompt = (contentType === 'ad' ? AD_PROMPT : PROPERTY_PROMPT) + OUTPUT_RULES
  const result = await generateWithFallback(apiKey, buildRequest(prompt, images))

  if ('error' in result) {
    return json({ ok: false, stage: 'gemini_error', detail: result.error })
  }

  const textOut = extractText(result.payload)
  if (!textOut) {
    // deno-lint-ignore no-explicit-any
    const finish = (result.payload as any)?.candidates?.[0]?.finishReason ?? 'unknown'
    return json({
      ok: false,
      stage: 'gemini_error',
      detail: `Gemini returned no text (model=${result.model}, finishReason=${finish}).`,
    })
  }

  const verdict = parseVerdict(textOut)
  if (!verdict) {
    return json({
      ok: false,
      stage: 'gemini_error',
      detail: `Could not parse JSON verdict (model=${result.model}): ${textOut.slice(0, 180)}`,
    })
  }

  return json({
    ok: true,
    stage: 'ai',
    model: result.model,
    approved: verdict.approved,
    category: verdict.category,
    confidence: verdict.confidence,
    reason: verdict.reason,
  })
})
