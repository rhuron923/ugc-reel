# Enhancor Seedance 2.5: pinned engine facts

Verified against the live API on 2026-09-25. The schema was assembled from a third-party client and live probes. If a job is refused with a 400, the error message names the field: read it, fix the body, resubmit only if it says nothing was queued. Re-check prices in your Enhancor dashboard from time to time; the `cost` field on each finished job is always the record.

## Endpoints (all handled by `bin/enhancor.sh`)

- `POST /api/seedance2.5/v1/queue` → `{"success":true,"requestId":"…"}`. Charged the moment a valid body is accepted. **No cancel endpoint.**
- `POST …/status {"request_id"}` → `status` in `PENDING · IN_QUEUE · IN_PROGRESS · COMPLETED · FAILED`, plus `result` (mp4 URL), `thumbnail`, `cost` (credits).
- Auth is the `x-api-key` header. The helper sends it; nothing else ever touches the key.
- `webhook_url` is required by the API; the helper fills in a sink and we poll `/status`.

## Modes (`mode` picks the workflow; there is no `type` field)

| mode | needs | notes |
|---|---|---|
| `text_to_video` | prompt | no references at all |
| `multi_reference` | `images` / `videos` / `audios` as **URLs**, at least one image or video | the normal mode when a product is in shot |
| `first_n_last_frames` | `first_frame_image`, optional `last_frame_image` | aspect forced to `adaptive` |
| `edit`, `extend` | `videos`, `duration: -1` | aspect `adaptive` |
| `multi_frame` | `multi_frame_prompts` array | segments sum 4–30 s |
| `ugc` | `products` + `influencers` image arrays | not used by this skill |
| `lipsyncing`, `voice_clone` | | not used by this skill (reels are caption-driven and silent) |

This skill uses `text_to_video` and `multi_reference`; `first_n_last_frames`, `edit` and `extend` only ever for repairs.

## Parameters

- `duration` integer **4–30** (or -1 for auto). **Always set it**: a missing duration defaults to 10 s and is charged.
- `resolution` `480p` / `720p`. `aspect_ratio` `9:16` (default), `16:9`, `1:1`, `4:3`, `3:4`, `21:9`, `adaptive`. `output_format` `mp4`.
- Reference limits: 30 images, 10 videos (under 30 s combined), 10 audios. References are fetched by URL; local paths and base64 do not work.
- `pass_faces: true` and `full_access: true` on every job (the helper sets both). The generator is unrestricted.
- Every clip arrives **with an audio track**; there is no switch to turn it off. Strip it in assembly (`-an`).

## Cost (linear: seconds × rate; 1 credit ≈ $0.001)

| mode family | 720p | 480p |
|---|---|---|
| text / image-driven (`text_to_video`, `multi_reference` with images only) | **269.3 credits/s** (13 s = 3,501 ≈ $3.50) | 122.2 credits/s |
| reference-video-driven (`edit`, `extend`, `multi_reference` with a video) | 165.5 credits/s | 75.1 credits/s |

A 4 s patch at 720p ≈ 1,077 credits ≈ $1.08. `bash "$ENH" cost <seconds> [720p|480p] [text|video]` prints the quote.

## Timing and unknowns

- A 13 s clip took about 6 minutes. Poll (`wait`), do not sit on chat.
- Unverified: whether a failed job is refunded, and how long result URLs stay live. **Download every result immediately.**
- Result CDN host: `d2i9jqncnkplwq.cloudfront.net`. API host: `apireq.enhancor.ai`. Both must be reachable from the shell.
