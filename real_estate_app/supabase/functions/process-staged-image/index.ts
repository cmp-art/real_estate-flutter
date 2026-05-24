// supabase/functions/process-staged-image/index.ts
//
// Webhook-triggered background worker for the Universal Upload Architecture.
// Triggered by a Supabase Database Webhook on storage.objects INSERT events
// pointing at the staging_media bucket.
//
// FLOW:
//   1. Flutter client uploads raw bytes → staging_media (private bucket)
//   2. storage.objects INSERT fires this webhook
//   3. This function downloads, transcodes with ImageMagick, publishes to
//      public_media at the deterministic path: same path, .raw → .jpg
//   4. Deletes the raw file from staging
//
// The Flutter client pre-computes the final public_media URL and stores it in
// the DB immediately, so no DB update is needed here. The image widget shows
// a shimmer until the file lands at that URL.
//
// HOW TO DEPLOY:
//   supabase link --project-ref qeddjlmexurmeiuslgqn
//   supabase functions deploy process-staged-image --no-verify-jwt
//
// WEBHOOK SETUP (Supabase Dashboard → Database → Webhooks):
//   Table: storage.objects
//   Event: INSERT
//   URL: https://qeddjlmexurmeiuslgqn.supabase.co/functions/v1/process-staged-image

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  ImageMagick,
  initialize,
  MagickFormat,
} from 'https://deno.land/x/imagemagick_deno@0.0.31/mod.ts'

// Initialise WASM once per isolate and reuse across warm invocations.
let magickReady: Promise<void> | null = null

serve(async (req) => {
  // Parse the webhook payload
  let payload: Record<string, unknown>
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400 })
  }

  const record = payload.record as Record<string, string> | undefined
  if (!record || record.bucket_id !== 'staging_media') {
    return new Response('Ignored', { status: 200 })
  }

  const filePath = record.name
  if (!filePath || !filePath.endsWith('.raw')) {
    return new Response('Ignored — not a .raw staging file', { status: 200 })
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  try {
    // 1. Download the raw bytes from the private staging bucket
    const { data: rawBlob, error: downloadError } = await supabaseAdmin
      .storage
      .from('staging_media')
      .download(filePath)

    if (downloadError || !rawBlob) {
      throw new Error(`Download failed: ${downloadError?.message ?? 'no data'}`)
    }

    const inputBuffer = new Uint8Array(await rawBlob.arrayBuffer())

    // 2. Process: auto-orient EXIF, strip all metadata, convert to JPEG.
    //    ImageMagick handles every format the client may upload — HEIC, AVIF,
    //    PNG, WebP, already-JPEG, etc.
    magickReady ??= initialize()
    await magickReady

    let outputBytes: Uint8Array | null = null
    ImageMagick.read(inputBuffer, (img) => {
      img.autoOrient()
      img.strip()
      img.write(MagickFormat.Jpeg, (data) => {
        outputBytes = new Uint8Array(data)
      })
    })

    if (!outputBytes) throw new Error('Transcode produced no output')

    // 3. Upload the clean JPEG to the public bucket at the predictable path.
    //    The Flutter client already computed this URL and stored it in the DB,
    //    so no DB update is needed — this upload makes that URL live.
    const publicPath = filePath.replace('.raw', '.jpg')
    const { error: uploadError } = await supabaseAdmin
      .storage
      .from('public_media')
      .upload(publicPath, outputBytes, { contentType: 'image/jpeg', upsert: true })

    if (uploadError) {
      throw new Error(`Upload to public_media failed: ${uploadError.message}`)
    }

    // 4. Clean up: remove the raw staging file
    await supabaseAdmin.storage.from('staging_media').remove([filePath])

    return new Response('Processed successfully', { status: 200 })
  } catch (error) {
    console.error('process-staged-image error:', error)
    return new Response('Internal Error', { status: 500 })
  }
})
