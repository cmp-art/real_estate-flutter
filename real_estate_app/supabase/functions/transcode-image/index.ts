// supabase/functions/transcode-image/index.ts
//
// Transcodes an uploaded image to a web-renderable JPEG using ImageMagick
// (WASM). Its job is to rescue formats the browser cannot decode itself —
// chiefly iPhone HEIC, which only Safari can read. On native the app already
// transcodes HEIC at pick time, so only the web/PWA client calls this.
//
// REQUEST:
//   POST  (raw image bytes in the body; Content-Type: application/octet-stream)
//   Headers: apikey + Authorization: Bearer <anon or user token>
//
// RESPONSE:
//   200  image/jpeg  (the transcoded JPEG bytes)
//   400  { error }   (empty / too-large body)
//   500  { error }   (could not decode the image)
//
// The image is auto-oriented (EXIF), downscaled so its longest side is at most
// 1280 px (matching the client's card crop), and encoded as JPEG quality 88.
//
// HOW TO DEPLOY:
//   1. Install Supabase CLI: https://supabase.com/docs/guides/cli
//   2. supabase login
//   3. supabase link --project-ref qeddjlmexurmeiuslgqn
//   4. supabase functions deploy transcode-image --no-verify-jwt
//
// QUICK TEST (after deploy):
//   curl -X POST \
//     -H "apikey: <SUPABASE_ANON_KEY>" \
//     -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
//     -H "Content-Type: application/octet-stream" \
//     --data-binary "@photo.heic" \
//     "https://qeddjlmexurmeiuslgqn.supabase.co/functions/v1/transcode-image" \
//     --output out.jpg
//
// USED BY:
//   lib/core/services/image_transcode_service.dart
//     ← lib/core/utils/image_helper.dart (cropToCard, web HEIC branch)

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import {
  ImageMagick,
  initialize,
  MagickFormat,
  MagickGeometry,
} from 'https://deno.land/x/imagemagick_deno@0.0.31/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// 15 MB — matches AppConstants.maxImageSize on the client. HEIC stills are far
// smaller; a larger body is almost certainly not a single photo.
const MAX_INPUT_BYTES = 15 * 1024 * 1024

// Longest-side cap for the output, matching the client's card crop width.
const MAX_DIMENSION = 1280
const JPEG_QUALITY = 88

// The WASM module is heavy to load, so initialise it once per isolate and
// reuse the promise across invocations.
let magickReady: Promise<void> | null = null
function ensureMagick(): Promise<void> {
  magickReady ??= initialize()
  return magickReady
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return jsonError('Method not allowed', 405)
  }

  let input: Uint8Array
  try {
    input = new Uint8Array(await req.arrayBuffer())
  } catch {
    return jsonError('Could not read request body', 400)
  }

  if (input.length === 0) return jsonError('Empty body', 400)
  if (input.length > MAX_INPUT_BYTES) return jsonError('Image too large', 400)

  try {
    await ensureMagick()

    const output: Uint8Array | null = ImageMagick.read(input, (img) => {
      // Apply the EXIF orientation HEIC files carry, then strip metadata so
      // the JPEG isn't bloated and doesn't leak GPS data.
      img.autoOrient()

      // Downscale only when larger than the cap; never upscale. greaterOnly
      // is ImageMagick's "1280x1280>" geometry flag.
      const geometry = new MagickGeometry(MAX_DIMENSION, MAX_DIMENSION)
      geometry.greaterOnly = true
      img.resize(geometry)

      img.quality = JPEG_QUALITY
      img.strip()

      // `data` is only valid inside this callback — copy it out.
      return img.write(MagickFormat.Jpeg, (data) => new Uint8Array(data))
    })

    if (!output || output.length === 0) {
      return jsonError('Could not decode image', 500)
    }

    return new Response(output, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'image/jpeg',
        'Cache-Control': 'no-store',
      },
    })
  } catch (e) {
    return jsonError(`Transcode failed: ${e instanceof Error ? e.message : e}`, 500)
  }
})
