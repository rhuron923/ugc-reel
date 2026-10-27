# ugc-reel

A Claude Code skill that turns a reference reel (or a list of beats you typed) into a short, caption-driven UGC-style product ad, generated on Enhancor's Seedance 2.5 with your own API key and cut on your own machine with ffmpeg.

You answer a short intake, edit a preview, say `generate` once, and get back a finished vertical reel plus a clean no-caption master in a dated folder. The whole script lives in burned-in captions. There is no voiceover and no lip-sync, which is a big part of what keeps AI footage believable.

If you are skimming, read "What it costs" below and the Enhancor step in Setup. The rest can wait until your first run.

## What to expect

The first time you open it, the skill interviews you. It explains itself, checks the command-line tools it needs and offers to install the missing ones, walks you through connecting your Enhancor account, then asks about your brand in three short blocks: your products (what they look like, how big they are, where a packshot lives), what your creators may and may not claim, and how your captions should sound. The answers go into a brand profile in a library folder you pick (default `~/UGC Library`) and are never asked again.

Start with reference reels. Each one you feed it gets broken down locally (cut detection, contact sheets, a whisper transcript, and Claude looking at the frames itself), adapted to your product, generated once, QC'd on frames, and cut. When you approve the result it is saved as a template. The first three to five templates are where the look and the caption voice get settled. After that you can skip references and describe a new reel from hand-written beats; the skill writes the prompt in the style your approved templates established. Beats first, with an empty library, also works. It just takes more rounds.

What it costs: generation is the only step that spends money, about $0.27 per second at 720p, so a 13 s reel is roughly $3.50, billed to your Enhancor credits. The skill always shows the price and waits for the typed word `generate` before spending anything. A queued job cannot be cancelled. Editing, captions, caption variants, frame QC and re-cuts are free. A 13 s clip takes Enhancor about six minutes to render.

It never posts or publishes. The brand profile is its only source of brand truth, so it does not browse the web or your site, and asks you when something is missing. Nothing gets installed without a yes from you.

## Setup (about ten minutes, once per machine)

1. Install the skill. Put the `ugc-reel` folder in `~/.claude/skills/` (or in a project's `.claude/skills/`). Open Claude Code and type `/ugc-reel`. Onboarding starts on its own.

2. Tools. The skill runs `bin/doctor.sh` and offers to install what is missing. On a Mac with Homebrew that is:

   ```bash
   brew install ffmpeg-full yt-dlp whisper-cpp jq
   ```

   `ffmpeg-full` matters: the plain `ffmpeg` formula no longer includes libass, which burns the captions. `yt-dlp` fetches pasted TikTok, Reel and Short links. `whisper-cpp` transcribes the reference's speech locally; the doctor also downloads its model (`ggml-base.bin`, about 150 MB) on request. On Linux, install the same tools with your package manager; the doctor prints what it could not find.

   On Windows the helpers run under Git Bash (which Claude Code uses as its shell), and `doctor.sh --install` uses winget:

   ```bash
   winget install -e --id Gyan.FFmpeg --source winget        # includes libass
   winget install -e --id yt-dlp.yt-dlp --source winget
   winget install -e --id jqlang.jq --source winget
   winget install -e --id Python.Python.3.12 --source winget # the python3 in WindowsApps is only a Microsoft Store stub
   ```

   whisper.cpp has no winget package, so the doctor unzips the official Windows build into `~/.config/ugc-reel/whisper/`. If a tool still shows as missing after installing, restart Claude Code so it picks up the new `PATH`.

3. Connect Enhancor. You need an Enhancor account with credits. Copy your API key from https://app.enhancor.ai/api-dashboard, then run this in a real terminal window:

   ```bash
   bash ~/.claude/skills/ugc-reel/bin/enhancor.sh setup-key
   ```

   It asks for the key with hidden input, tests it with a free call that queues nothing, and stores it in your macOS Keychain (on Linux, in `~/.config/ugc-reel/enhancor.key` with permissions 600; on Windows, in the same file, locked to your user with `icacls`). On Windows, run it in a **Git Bash** window, not PowerShell, where `bash` may start WSL instead. The key is never typed into chat, never printed, never written into a project file. If you paste it into chat by mistake, rotate it in the Enhancor dashboard and run `setup-key` again.

4. File staging (optional). Enhancor fetches product images by URL. If your packshots already sit at public URLs (your website, a CDN), you are done. If they are local files, or you want beat repairs (which upload a still cut from a take), give the skill somewhere to put files. Edit `~/.config/ugc-reel/config.env`:

   - `UGC_UPLOAD=s3` with `UGC_S3_BUCKET=<your bucket>` uses the AWS CLI against any S3-compatible store (AWS S3, Cloudflare R2, Backblaze B2, MinIO; set `AWS_ENDPOINT_URL` for the non-AWS ones and `AWS_PROFILE` if you use one). Uploads land under `UGC_S3_PREFIX/` only and the skill hands Enhancor a 24-hour presigned link.
   - `UGC_UPLOAD=cmd` with `UGC_UPLOAD_CMD="<command>"` runs any command that takes a file path as its single argument and prints one public URL.
   - `UGC_UPLOAD=none` (the default) means packshots must have public URLs and beat repairs are off. Everything else works.

`bash ~/.claude/skills/ugc-reel/bin/enhancor.sh check` tells you at any time whether the key, staging and result downloads are in order. It is free.

## For teammates (Grace Coffee)

The skill lives in a private GitHub repo: https://github.com/rhuron923/ugc-reel (ask Ryan to add you as a collaborator).

1. **Install.** In a terminal (Git Bash on Windows):

   ```bash
   git clone https://github.com/rhuron923/ugc-reel.git ~/.claude/skills/ugc-reel
   ```

   Then open Claude Code and type `/ugc-reel`. Onboarding checks your tools and connects your Enhancor key (Setup steps 2 and 3 above).
2. **Use the shared library, don't make a new one.** Grace's brand profile, playbooks, templates and campaigns live in Ryan's OneDrive folder `UGC Library`. Once Ryan shares it with you, open it in OneDrive on the web and choose "Add shortcut to My files" so it syncs to your computer. When onboarding asks where to keep the library, give it that synced folder's path. The skill then finds `brand.md` there and skips the brand interview.
3. **Ad naming sheet.** Approving cuts for testing reads and writes the "Grace Coffee Test Name Generator" Google Sheet. You need edit access to it and the Google Sheets connector enabled in Claude.
4. **Updates.** `git -C ~/.claude/skills/ugc-reel pull` picks up changes. Don't edit the installed copy directly; send changes to Ryan or open a pull request.

Each person's Enhancor key stays on their own machine and is never in the repo. Generation bills whichever Enhancor account that key belongs to.

## A run, stage by stage

1. Route and folder. New template from a reference, from written beats, or a re-run of a saved one. Campaigns go to `<library>/campaigns/<date - brand - product>` unless you name a folder.
2. Intake. Three questions: which product, the reference (file or link), what to highlight. Then one follow-up about elements that must survive into the prompt.
3. Breakdown (reference route only). `bin/analyze.sh` measures the reel and writes contact sheets, cut candidates and a transcript; Claude reads the frames itself and writes a short shot-by-shot breakdown.
4. Preview. The full plan: on-screen captions, timed beats, the complete prompt, which packshots are attached, and the price. Edit anything. Say `generate` when it is right.
5. Generation. One take, submitted once, polled until done, downloaded immediately.
6. QC and assembly. Frames are checked against the product rules (label facing camera, correct scale, blank wardrobe, clean hands). The take is cut and captioned straight away, flaws trimmed around where possible, and delivered with the QC notes alongside. One bad beat can be patched for about a dollar instead of re-rolling the take.
7. Save. Once you approve the result, the skill offers to save the exact prompt as a template in your library.

Re-running a saved template asks one question ("want to tweak any variables?") and changes only what you name.

## Existing footage and test-ready files

You don't always need a generated take. Give the skill a video you already have (a creator clip, a past ad, a phone video) and it writes several caption variants for it, each testing a different hook, shows you the sheet, and renders them when you say `render`. It costs nothing, since no credits are spent.

Whichever way a reel was made, once you say which cuts are approved for testing, the skill makes a 1100x1080 feed version of each one. It crops from the clean master, checks the framing on stills first, and re-burns the captions at the new size. It then files the pair in `Approved for testing/` in the campaign folder under their ad names, built the way your naming sheet builds them (linked in the brand profile under "Ad naming"; rules in `references/ad-naming.md`). The vertical and feed cuts are separate ads that differ only in `sz-9x16` / `sz-1100x1080`. Before saving, it shows you every name and any new values it needs to add to the sheet's glossary. On your OK it logs a row per ad in the generator tab and checks that the sheet's formula produces the same names. Change the size with `feed format` in your brand profile.

## The caption humanizer (optional)

Captions are written under a fixed set of creator-voice rules. On top of that you can switch on a two-pass check for the signs of AI writing (`caption_humanizer: on` in your brand profile, or just ask for "humanized variants" in a run). Pass 1 looks at words and phrasing (dashes, "not X but Y", lists of three, hype words). Pass 2 looks at the shape of the caption set (a moral-of-the-story closer, a too-tidy arc, every variant sharing one skeleton). The rules are in `references/caption-humanizer.md`, so nothing else needs installing; if you have the `humanizer` and `structural-humanizer` skills installed, the skill uses those instead. Either way it keeps every fact and claim as written and shows you the before and after.

Whether a humanized caption set actually performs better on the platform is an open question. It is off by default for that reason. Turn it on, run a few A/B variants, and decide from your own numbers.

## Concept playbooks

If you have notes on ad concepts that have worked (yours, or ones a peer brand shared), put them in `playbooks/` in your library and list them in your brand profile under "Concept playbooks". The skill reads them before writing any caption set, uses their principles and structures in your creator's voice, says which concept each reel draws on, and drops any line that breaks your claims rules. Caption variants default to a hook test: the same body, a different opener each.

## Folder layout

```
ugc-reel/
  SKILL.md                      the workflow Claude follows
  README.md                     this file
  bin/enhancor.sh               the only thing that talks to Enhancor (key, check, cost, submit, status, wait, upload)
  bin/_platform.sh              macOS / Linux / Windows differences, sourced by the helpers
  bin/doctor.sh                 tool check and installer
  bin/analyze.sh                local reference analysis
  bin/reformat.sh               feed reformat (1100x1080) with captions re-burned; also normalises existing footage
  bin/make-ass.py               caption JSON → .ass for burn-in
  bin/config.env                defaults, no secrets (overridden by ~/.config/ugc-reel/config.env)
  references/                   engine facts, brand profile template, breakdown template, assembly recipes, ad naming, caption humanizer
```

Your library (default `~/UGC Library`) holds `brand.md`, `templates/`, `packshots/`, `playbooks/` and `campaigns/`. Skill updates never touch it.

## Things worth knowing

- Every job bills your own Enhancor account and cannot be cancelled once accepted.
- Enhancor returns every clip with an audio track; the skill strips it. Reels are silent masters with burned-in captions.
- Enhancor's prices and limits were last verified on 2026-09-25 and are listed in `references/enhancor-api.md`. The `cost` field on each finished job is the record.
- Nothing in this folder is secret, so the folder is safe to share. Never put an API key in `config.env` or anywhere in it.
- Leave `enhancor.sh submit` on "ask" in your Claude Code permissions. That prompt is the credit gate.

## Attribution

The workflow is adapted from Miko's Video Ad Stack and Second-by-Second Video Breakdown SOP. The caption humanizer is adapted from blader/humanizer (MIT), NulightJens/humanizer-stack, Wikipedia's WikiProject AI Cleanup "Signs of AI writing" (CC BY-SA 4.0) and Russell et al. 2026 (StoryScope).
