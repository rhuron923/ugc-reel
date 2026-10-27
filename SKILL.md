---
name: ugc-reel
description: Guided UGC video-ad workflow for any brand. Breaks down a reference reel locally (ffmpeg + whisper + your own eyes on the frames), writes a caption-driven master prompt, generates one take on Enhancor's unrestricted Seedance 2.5 with the user's own API key, QCs the frames, assembles the reel with burned-in captions, and saves approved winners as reusable templates. Later templates can be written from hand-typed beats. Use on /ugc-reel or whenever asked to make a UGC-style product reel, TikTok/Reels ad, or creator-style video with the Enhancor pipeline.
---

# /ugc-reel — UGC video ad workflow (local analysis → Enhancor generation)

Three routes into the same generator: **A — new template from a reference reel**, **B — re-run a saved template**, **C — new template from hand-written beats**, plus one route that generates nothing: **D — caption variants of existing footage**. Start immediately when invoked. Collect inputs at the stage that needs them, reuse anything already supplied, and never ask twice.

Route A: **0 Route + folder → 1 Short intake → 2 Local reference breakdown → 3 Editable ad preview → 4 Generation → 5 Save the template → 6 Approved for testing.**
Route B: **0 Route + folder → 1b Pick a template → 2b Tweak question → 3 Editable ad preview → 4 Generation → 6 Approved for testing.** Route B never saves a template: a re-run, however much it is tweaked, is not a new template.
Route C: **0 Route + folder → 1c Beats intake → 3 Editable ad preview → 4 Generation → 5 Save the template → 6 Approved for testing.** Route C is for a library that already holds approved templates (see Onboarding → What to expect).
Route D: **0 Route + folder → 1d Footage intake → 2d Footage check → 3d Caption variant sheet → 4d Render the variants → 6 Approved for testing.** Route D spends no credits and never saves a template.

Every route ends the same way: when the user approves variants for testing, Stage 6 reformats them to the feed size (1100x1080) and saves each one under its ad name from the brand's naming sheet.

Before any of that, the **Onboarding** section runs once per machine and the **Environment gate** runs on every invocation.

The creative rules in this file (Defaults, Prompt-writing rules, Caption copywriting, the Stage 2b discipline, the three gates) are doctrine and do not bend. The brand's own facts come from `brand.md` in the library and nowhere else. The **Plumbing** section is the only place that says *how* a file, a job or a frame moves; every stage points at it and nothing improvises a transport.

## Paths used throughout

```bash
BIN="$(for d in "$HOME/.claude/skills" "$PWD/.claude/skills"; do find -L "$d" -maxdepth 4 -path '*/ugc-reel/bin/enhancor.sh' 2>/dev/null; done | head -1 | xargs -I{} dirname {})"
ENH="$BIN/enhancor.sh"
[ -f "$HOME/.config/ugc-reel/config.env" ] && . "$HOME/.config/ugc-reel/config.env"
eval "$(bash "$BIN/doctor.sh" --env)"   # FF, FP, PY (a working Python 3), WHISPER, WHISPER_MODEL
echo "BIN=$BIN LIBRARY=${UGC_LIBRARY:-unset} PY=${PY:-none}"
```

Always invoke the helpers as `bash "$ENH" …`, `bash "$BIN/doctor.sh" …`, `bash "$BIN/analyze.sh" …`; an unzipped copy may have lost its executable bits. Call Python as `"$PY"`, never a bare `python3` (on Windows that is a Microsoft Store stub). If `BIN` is empty the skill was installed without its `bin/` folder: say so and ask the user to reinstall the full folder.

**Windows.** The helpers run under Git Bash (Claude Code's Bash tool on Windows). `bin/_platform.sh` handles the differences: it finds a real Python, adds winget's tool folders to `PATH`, and strips the CRLF line endings native Windows programs print. Tools install with winget instead of Homebrew. The API key is stored in a file only the user can read, not a keychain. Anything the user runs themselves (`setup-key`) must be run in a **Git Bash** window, not PowerShell or cmd, where `bash` may resolve to WSL.

**The library** (`$UGC_LIBRARY`) is a folder the user owns, outside the skill, so skill updates never touch it. It holds `brand.md` (the brand profile), `templates/<slug>.md` (approved templates), `packshots/` (local product images), `playbooks/` (concept playbooks the brand has collected, listed in `brand.md` → Concept playbooks), and `campaigns/` (the default campaign location). Nothing about a brand is stored inside this skill folder.

---

## Onboarding — runs once, on the first invocation on this machine

Trigger: `~/.config/ugc-reel/config.env` is missing, or `$UGC_LIBRARY/brand.md` does not exist. Run the four parts in order, in a guided way, one short message per part. Skip parts that are already done (a brand profile exists but the tools are missing → only the tools part).

### 1. Say what this is and what to expect (one message, no questions)

Tell the user, in plain words and roughly this order:

- **What it makes.** Short vertical UGC-style ads (4–30 s) for their products: one AI-generated take per reel on Enhancor's Seedance 2.5, silent, with the whole script carried by burned-in captions, cut and captioned locally with ffmpeg. No voiceover, no lip-sync.
- **What it costs.** Generation is the only thing that spends money: about $0.27 per second at 720p (a 13 s reel ≈ $3.50), billed to their own Enhancor credits. The skill always shows the price and waits for the typed word **generate** before spending anything. A queued job cannot be cancelled. Editing, captions, variants and QC are free.
- **What a run looks like.** A short intake, a preview they can edit (captions, beats, the full prompt, the price), one generation (about 6 minutes for a 13 s clip), frame QC, then the finished reel plus a clean no-caption master in a dated campaign folder. Nothing is ever posted or published by the skill.
- **The recommended path.** *Begin by feeding it reference reels.* Each reference it breaks down becomes a tested, approved template in the library, and the first three to five templates are where the brand's look, product handling and caption voice get settled. After that they can skip references and simply **describe a new template from hand-written beats** (Route C); the skill writes the prompt in the style the approved templates established. Doing beats first, with an empty library, works but takes more rounds.
- **What it needs from them.** An Enhancor account with credits and its API key (next step), a few command-line tools on this machine (the skill checks and offers to install them), and ten minutes for a brand interview that is saved and never asked again.

Keep it to one screen. No marketing voice.

### 2. Tools check, with an offer to install

Run `bash "$BIN/doctor.sh"` and show its report in two lines (what is OK, what is missing). If anything is missing on a Mac with Homebrew or on Windows with winget, ask exactly once:

> "Install the missing tools now? It runs `brew install …` (and downloads the whisper model, ~150 MB) on this machine."

(On Windows say `winget install …` and that it also downloads whisper.cpp from its GitHub releases.)

On yes: `bash "$BIN/doctor.sh" --install` and show the result. On Windows, if a tool still shows MISSING right after a successful install, its folder is not yet on this session's `PATH`; ask the user to restart Claude Code and re-run the doctor. On no: say which features are off (no libass ffmpeg = no captions = no reels; no yt-dlp = send files instead of links; no whisper = words in references must come from the user) and continue. If Homebrew itself is missing, point at https://brew.sh (that install asks for their password, so it is theirs to run). On Linux, show the commands and wait for the user. Never install anything the user did not say yes to.

### 3. Connect Enhancor (their own account, their own key)

Explain in four lines: they need an Enhancor account with credits; the API key is at **https://app.enhancor.ai/api-dashboard**; the key is stored in the macOS Keychain (on Linux and Windows, in `~/.config/ugc-reel/enhancor.key`, readable only by them) by one command that asks for it with hidden input and tests it for free; it is never typed into chat, never printed, and never written into any project file.

Then ask them to run, in a real terminal window (in the desktop app, offer to open a terminal tab for them; on Windows it must be a **Git Bash** window, and the path is the forward-slash form under `~/.claude/skills/`):

```bash
bash "<path to>/ugc-reel/bin/enhancor.sh" setup-key
```

Wait for them to say it is done, then run `bash "$ENH" check` yourself and confirm `READY.`. If they paste the key into chat anyway, tell them to rotate it in the Enhancor dashboard and run `setup-key` again with the new one.

**File staging (optional, explained once).** Enhancor fetches reference images by URL. If their packshots already have public URLs (their website, a CDN, a public bucket), nothing else is needed. If packshots are local files, or they want beat repairs (which upload a still from a take), they need a place to stage files: their own S3-compatible bucket (`UGC_UPLOAD=s3`) or any command that uploads a file and prints a URL (`UGC_UPLOAD=cmd`). Record the choice in `~/.config/ugc-reel/config.env`; `none` is a fine answer and can be changed later (README.md has the details).

### 4. Brand interview → `brand.md`

Ask first where the library should live, with a default:

> "Where should I keep your brand profile, templates and campaigns? Default: `~/UGC Library`."

Create it, write `~/.config/ugc-reel/config.env` with `UGC_LIBRARY="<path>"` (and `UGC_UPLOAD=…` from part 3), then interview in **three short blocks**, one message each, waiting for answers. Reuse anything already said in the conversation.

**Block 1, the products.** Brand name. For each product that can appear in a reel: the spoken name (what a creator would call it), the label text as printed, the size, a physical description (shape, colour, cap, print, materials), a scale anchor against a familiar object, and a packshot (public URL, or a local file path to copy into `packshots/`). Which product is the hero. If a product is ever shown leaving its pack, one exact phrase for its texture.

**Block 2, what can be said.** The talking points in priority order. Claims the creator may make, word for word where it matters. Claims that must never be made (offer the usual list: stats, studies, "clinically proven", medical claims, competitor names, prices, media mentions, invented credentials, and ask what to add). Words that would make a caption read like a listing. The first-person testimonial policy (`flag` by default, explained in one line: an AI creator is not a real customer, so lines claiming personal results get a ⚑ for approval).

**Block 3, look and delivery.** Default aspect and resolution (offer 9:16 at 720p). Caption font preference (Montserrat if installed, else Arial Bold). The exact product-name caption to burn under the pack. Two or three lines on who the creator is and how she talks. And the optional caption humanizer, explained in two lines: *off* means captions are written under the house rules only; *on* means every caption set and every variant also goes through a two-pass "signs of AI writing" check (`references/caption-humanizer.md`) before it is shown, and the before→after is listed. Default off.

Write `$UGC_LIBRARY/brand.md` from `references/brand-profile.md` with the answers, show it in full, and ask for corrections once. Then say onboarding is complete, and go to the Environment gate and Step 0 of their first run. Never ask any of this again; to change something they say "update the brand profile" and you edit the file.

---

## Defaults

- **Generator: Seedance 2.5 on Enhancor, unrestricted.** Every generation goes through `bin/enhancor.sh` (see Plumbing) to `apireq.enhancor.ai/api/seedance2.5/v1`, always with `pass_faces: true` and `full_access: true` (the helper sets both). Engine facts and prices: `references/enhancor-api.md`. Use another provider only if the user asks.
- **Resolution and aspect** from `brand.md` Defaults (720p, 9:16 unless changed).
- **Feed size for approved test variants: 1100x1080**, or `feed format` in `brand.md` Defaults when it is set. Produced only in Stage 6, from the clean master, never by cropping a captioned cut.
- **One generation per template under 30 s.** Never split a sub-30 s template into multiple clips: not for length, not for structure, not for QC convenience. An unbroken take is what makes a routine read as real. Recreate a reference's cut rhythm with jump cuts in assembly, which cost nothing. Split only when the target genuinely exceeds the 30 s limit.
- **Captions only, silent master.** Every reel is 100% caption driven: no voiceover, no lip sync, no spoken dialogue, no character framed mid-sentence. Enhancor has no switch to turn audio off, so write "no speech, mouth closed" into the prompt and strip the track in assembly (P6 encodes with `-an`). Captions are burned in during assembly, where rewording and retiming are free.
- **Mode: guided walkthrough.** Pause at each stage and show the output. Keep every stage lean: no research, no recaps, no documents the user did not ask for. Run end-to-end only if the user explicitly asks and gives a credit budget.
- **The queue call spends money and cannot be cancelled.** Never send an "experimental" or probe body to `submit`; only the approved, costed job.

## Prompt-writing rules (apply to every prompt sent to the model)

The generator is unrestricted, so there are no content-avoidance rules here: describe the scene, the person and the wardrobe as directly as the reel needs. What follows is about product fidelity and clean footage.

1. **Name the shot type and the action.** Open each beat with its shot type (wide shot low angle, tight shot on her hands, medium shot from behind), then say what happens. One action per beat; no contradictory simultaneous actions.
2. **Write constraints as positive description.** Say what the frame holds, not a list of what it must not contain. Reserve outright prohibitions for things that must never appear at all (captions, other brands' logos, back-of-pack text) and verify those on frames anyway.
3. **The pack is label-out, per `brand.md` → Label-out rule.** Like a stage actor it may pivot side to side, but it never shows its back to the audience. Every beat in which the pack is in frame says so in positive terms, for example: "the printed front faces the camera throughout; when she turns it, it pivots a little to one side and back, and the printed front is the only face of the pack ever seen." Applies to hands-on beats too: a palm may cover part of the front, never turn it away.
4. **Physical scale is fixed and stated in every prompt that shows a pack.** Use the scale anchor from `brand.md` (against a hand, a phone, a familiar object), and when two packs share a frame, state their relation from the profile. Write the anchor into the prop line ("a squeeze tube about the height of a phone held upright, no larger"). Scale is checked on frames like a label is.
5. **Wardrobe and accessories carry no marks.** In every scene with a character, the prompt states that all clothing and every accessory is plain, in blank unmarked material with zero text, icons, logos, emblems, brand-like patterns or distinguishing marks. Say it once as a sentence in the subject block and repeat "blank" or "unmarked" on each named garment.
6. **Show the person's look in the subject block once, then leave it.** Age, build, skin, hair, wardrobe, accessories: stated in full in one SUBJECT paragraph and never re-described per beat.
7. **Product texture is one fixed phrase.** If the product is shown leaving its pack, every such beat uses the exact texture line from `brand.md`, word for word. Video models drift on texture ("translucent" renders water-clear); the fixed phrase is what holds it.
8. **No camera device in the frame.** Say "as if the camera were propped on the floor in front of her", never "filmed from a phone on a tripod": naming the device puts the device in the shot.

If a job comes back with an error or an unexpected result, re-check wardrobe, framing and beats against the approved plan and say what moved before re-costing anything.

## Caption copywriting (every on-screen line)

The captions are the whole script, so they carry the whole sell. They are written by **her**, a creator who figured something out and is putting her friends on, never by the brand. If a line could sit on the back of the pack, in a marketplace bullet or on a website feature grid, it is wrong. Helpful and persuasive, not informative.

### Voice

- **Text-a-friend register.** All lowercase, contractions, fragments. One word in CAPS for emphasis at most once or twice per reel ("then THIS goes on"). No title case, no tidy written sentences, no brand punctuation (no "™", no "!" stacks, no ": " feature labels).
- **Current short-form phrasing, used lightly.** "pov:", "no because…", "not me…", "tell me why…", "the way…", "ok but", "literally", "this is your sign", "you're welcome", "trust me", "save this". One or two per reel, a sprinkle, not a costume. Skip anything that already sounds dated.
- **Problem and feeling first, product second.** The hook material is the pain the audience already knows. The product is the answer she reveals, never the headline.
- **Show, don't spec.** She reacts to what the viewer is watching ("ok watch", "that's it. that's the whole thing") instead of describing the product's properties.
- **Short.** One idea per caption, roughly 2–7 words, two lines max, readable in the time it is on screen. The one exception is the static POV line in a sub-10 s reel (below), which may run to four lines because it stays up the whole time.
- **Plain text only.** No emoji; the burned-in caption font does not render them.

Banned brand-speak in captions: the generic list (formula, technology, nourishing, defense, protects against, ideal for, perfect for, suitable for, all types, made in, fl oz, ingredient lists, any step numbering that reads like instructions on a box) plus the brand's own list in `brand.md`. The product-name caption is the one place the brand's words appear.

### Caption count — under 10 s is one or two captions (hard rule)

A reel under 10 s carries **one or two captions in total**, never the four-step arc below. Two formats, nothing else:

- **Static POV**: one caption, on screen from the first frame to the last: `POV you are done with <pain> so this time you <action>`, or `POV <the result she is enjoying right now>`. "POV" in caps, the rest lowercase. It may wrap to four lines at a slightly smaller size (54–56).
- **You hate / but now**: two captions, split on the reveal cut (the moment the result shows): `you hate <pain>` → `but now <result>`. The second caption is the payoff and follows the never-end-on-a-feature rule.

No separate product-name line in these; the count includes it. When offering caption variants on a short reel, give some of each format.

### The arc (reels of 10 s and longer)

1. **Hook, the first caption, on screen by 0.3 s.** A curiosity gap, a relatable pain, or a pattern interrupt that stops a scroll with the sound off. It opens a loop the ending closes.
2. **Build.** The routine in her voice, moving fast, teasing the payoff ("ok now watch", "trust the process").
3. **Product moment.** She points at it casually ("then THIS", "this is the part"). The bottom caption under the pack is exactly the product-name caption from `brand.md`.
4. **Payoff, the last caption.** Closes the hook's loop with the result or the feeling, or sends them off with a nudge to save/share/try it.

### Never end on a feature (hard rule)

The last caption is **never** a product feature, usage instruction, spec, hedge or disclaimer. Ending on a spec kills the reel: it reads like a listing and gives the viewer nothing to feel. Features may appear mid-reel only if she says them in her own voice and they earn the space; the ending is always the payoff. Endings that work: "<pain>? not this year" · "this is your sign" · "you're welcome" · "save this" · "tell your friend who needs it".

### Claims still apply

The creator voice does not loosen `brand.md`. Every caption passes its MAY / MUST NOT lists: no stats, no "100%", nothing medical, nothing on the brand's red-line list. Where a claim needs "helps", say it in her voice, never as a bolted-on parenthetical hedge, or make the line about the feeling instead of the claim. First person is her natural voice, so use it, and apply the testimonial policy: with `flag`, every line that claims her own use or result gets ⚑ and an unflagged alternative in the same slot, so approval never blocks the reel.

### Concept playbooks (when `brand.md` lists any)

Before drafting any caption set, caption variant sheet or Route C beats, read every playbook listed in `brand.md` → Concept playbooks. Use its principles to shape the copy and its concept skeletons as starting structures, always rewritten in the brand's own voice. A playbook ranks below everything else in this section and below `brand.md`: where a playbook line breaks a claim, a banned word or a hard rule, the line is dropped (playbooks list their known conflicts; check anyway). In the plan or variant sheet, say in one line which playbook concept or principle a reel draws on, or "none".

### Optional: the caption humanizer

Controlled by `caption_humanizer` in `brand.md` Defaults, and switchable per run ("humanized variants please" / "skip the humanizer this time"). When **on**, after every caption set or variant batch is drafted and before it is shown:

1. If the `humanizer` and `structural-humanizer` skills are available in this session, invoke them on the caption table (pass 1 then pass 2) with these constraints stated in the request: keep every fact, claim and number; keep the hard caption rules above; captions stay 2–7 words; vary the shape between variants.
2. Otherwise apply `references/caption-humanizer.md` yourself, following its "How to run it on a caption set" checklist.

Then show the final captions with a short before→after list for the lines that changed. The humanizer never adds specifics, never overrides a hard rule, and never produces a new default (if every variant now opens the same way, it has failed; redo the shape pass).

### Before showing captions, check

- Read every line as her. Would a real creator post this, or does it sound like a brand wrote it?
- Under 10 s: one or two captions total, in one of the two short formats?
- Does the hook work with the sound off, in under a second?
- Does the last line close the hook and make you *feel* something? If it is a feature, rewrite it.
- Any banned brand-speak, spec or parenthetical left? Remove it.
- Claims pass; ⚑ lines flagged with alternatives; humanizer pass done if it is on.
- Playbook principles applied where they fit, and no playbook line that conflicts with `brand.md` survived.

---

## Environment gate — the first thing every run does

Runs before Step 0, before resuming any campaign, before any question. Never discover a blocker after the user has started answering, and never offer to "do everything up to the submit" as a consolation.

```bash
bash "$BIN/doctor.sh" >/dev/null && echo TOOLS_OK || bash "$BIN/doctor.sh"
bash "$ENH" check
```

- Both pass → continue silently (one line: "tools and Enhancor ready").
- Doctor reports a missing required tool → Onboarding part 2 (the install offer), then re-run.
- `NO_KEY` → Onboarding part 3. `Enhancor rejected your key` → same `setup-key` step with a fresh key. A `WARNING` about the API or CDN host → network problem; say so and stop.
- No `brand.md` → Onboarding part 4.
- **Route D and Stage 6 never call Enhancor.** If the user has already said they are bringing existing footage (or are filing approved variants), an Enhancor failure is one line ("Enhancor isn't connected; that only matters for generating new takes") and the run continues. The tools check still blocks: no libass ffmpeg means no captions.
- **Never** ask the user to paste the key into chat, print it, echo it, put it on a command line or write it to a file.

Record the result in `run-state.md` (helper path, ffmpeg path, library) so a resumed campaign skips a passing gate.

### Permissions (the only prompt that should ever appear is the one that spends credits)

Allow the Bash patterns the plumbing uses (`ffmpeg`, `ffprobe`, `yt-dlp`, `whisper-cli`, `fc-list`, `awk`, `"$PY" "$BIN/make-ass.py"`, `bash "$BIN/doctor.sh"`, `bash "$BIN/analyze.sh"`, `bash "$BIN/reformat.sh"`, and `bash "$ENH" check|cost|upload|wait|status`). **Leave `bash "$ENH" submit` on ask**: that prompt is the credit gate and lines up with the user's typed **generate**. If a run hits any other prompt, name the command in the final report so a rule can be added. Never work around a prompt by picking a different tool.

## Step 0 — Route and folder, one message

Unless `run-state.md` for an in-flight campaign already answers it (then resume that campaign and say so), open with **one** short message that asks both things:

> "New template from a reference reel, from written beats, one of your saved templates (N saved), or caption variants of a video you already have?
> I'll save this campaign to **<default folder>**; say a different folder if you want one."

- Saved templates are the files in `$UGC_LIBRARY/templates/`. If there are none, say so in one line and offer A, C or D.
- If the user's opening message already says they have existing footage to re-caption, skip the question: it is Route D, and only the folder line is shown.
- If they only want to file variants already approved in an earlier campaign, resume that campaign and go straight to Stage 6.
- Default folder: `$UGC_LIBRARY/campaigns/<YYYYMMDD - Brand - Product>`, or inside a folder the user named in this conversation.
- Create the campaign folder, write `run-state.md`, and do not ask about destinations again.

## File naming

Every deliverable file the user will open or share is named `YYYYMMDD - Hook vX`: the date produced (local time), a 2–5 word title-case label for the hook taken from the approved script (filename-safe), and the preview version it came from. Apply it to the final video, the clean no-caption master (`… vX (no captions).mp4`), extra caption/cut variants (`… vX (variant B).mp4`), and each version's documents (`production/… vX - plan.md`, `… - master prompt.md`). Never overwrite an existing file; a new version gets a new vX. Working files keep the structural names below.

- **Route D** uses the same pattern. The hook label names the footage's concept (what the clip shows, e.g. "Kitchen Pour Over"), not any one variant's hook, so every caption variant of one clip groups together. The lead variant is unsuffixed and the rest are `(variant B)`, `(variant C)`, …; the clean master is the trimmed source, `… vX (no captions).mp4`; the version's document is `production/… vX - caption variants.md`, which maps each letter to its captions.
- **Cuts approved for testing (Stage 6) take ad names instead**, built from the brand's naming sheet (`brand.md` → Ad naming, mechanics in `references/ad-naming.md`): `<creative file name> - <creator> - f-video - as-… - m-… - cg-… - h-… - p-… - … - sz-9x16`. The 9:16 and the 1100x1080 cut of one variant are separate ads whose names differ only in `sz-`. The working names above stay on review cuts; ad names are only for what will run.

**Only the newest version sits at the campaign root.** When a new version of a reel is delivered, move that reel's older finals (every file of the earlier vX, variants and clean master included) into `Previous versions/` in the campaign folder, never deleting them. A caption-only re-cut reuses the same take, so copy the previous clean master to the new vX name before moving the old one.

## Campaign folder

```
breakdown/<reference-id>/        analyze.sh output + breakdown.md   (Route A; Route D's footage check)
production/YYYYMMDD - Hook vX - plan.md
production/YYYYMMDD - Hook vX - master prompt.md
production/YYYYMMDD - Hook vX - caption variants.md   (Route D)
production/run-manifest.json
production/clips/                raw takes, patches, stills, caption json/ass, segment files, feed caption copies
YYYYMMDD - Hook vX.mp4           finals, at the campaign root (newest version only)
Approved for testing/            the upload set (Stage 6): each approved 9:16 cut + its 1100x1080 feed cut, under ad names, + ad names.csv
Previous versions/               superseded finals, moved here when a newer vX is delivered
run-state.md
```

`run-state.md` records: route, template slug if Route B, campaign folder, completed stages, current preview version and hook label, packshot URLs used, pending Enhancor request ids, the source footage path and audio choice (Route D), which variants are approved for testing and their crop settings, and the next action. On every invocation check for it first and **resume** rather than redo work or duplicate paid jobs. Never write credentials, tokens or upload URLs into any file other than the manifest's staged-still URLs (they expire).

---

## Plumbing — the seven operations

One recipe per operation. Use them exactly; do not invent an eighth.

### P1 · Get a reference clip in (local)

`bash "$BIN/analyze.sh" "<file or link>" "breakdown/<ref-id>" [--start S --end E] [--fps 3]`. A pasted TikTok / Reel / Short link is fetched with yt-dlp; a file is copied. If the link yields nothing, say exactly what is missing and ask for the file. Nothing is uploaded anywhere.

### P1b · Stage a file for Enhancor (local packshots, anchor stills)

Enhancor takes **URLs**, never local paths. Packshots with public URLs in `brand.md` are used directly. For anything else: `bash "$ENH" upload "<local file>"` prints a URL (24 h if S3-presigned). Record it in `run-state.md` / the manifest. If `UGC_UPLOAD=none`, say so and either continue without that file or point at README.md to enable staging; never substitute a different upload host.

### P2 · Submit a generation

Write the request body to `production/clips/job-v<X>.json`, then submit it once:

```
{
  "mode": "multi_reference",          // "text_to_video" only when there are no references at all
  "prompt": "<master prompt, verbatim from the approved version>",
  "images": ["<packshot URL>", ...],  // multi_reference: at least one image or video; URLs only
  "duration": <int seconds, 4-30>,    // ALWAYS explicit; a missing duration defaults to 10 s and is charged
  "resolution": "720p",
  "aspect_ratio": "9:16"              // "adaptive" for edit/extend/first_n_last_frames
}
```

`bash "$ENH" submit production/clips/job-v<X>.json`. The helper refuses a body with no `mode`, `duration` or `resolution`, fills in the house defaults and the webhook sink, and prints the response.

- **`{"success":true,"requestId":"…"}`** → write the id to `production/run-manifest.json` **before** anything else (non-secret params, image URLs, the id, expected credits, status `generating`), then P3.
- **HTTP 400** → nothing was queued or charged. Read the message, fix the body, resubmit, show the user what changed.
- **HTTP 401 / 403** → the key was rejected. Stop; the user runs `setup-key` with a fresh key.
- **Timeout / no answer** → the job may exist and may be charged. Do **not** resubmit. Ask the user to check the Enhancor dashboard for the newest job and adopt its id if it matches.

Cost: there is no preflight endpoint. Quote with `bash "$ENH" cost <seconds>` in Stage 3; the `cost` on the finished job is the record.

### P3 · Wait, show, fetch

`bash "$ENH" wait <requestId>` polls every 10 s for up to 15 minutes. Exit code 2 means still running, not lost: run it again. No commentary between polls. `COMPLETED` → continue. `FAILED` → stop and report the message; do not retry blind (refunds are unverified; the user checks their balance, and any resubmission is a new costed decision).

Bring it home immediately: `curl -fL --retry 3 -o "production/clips/take-v<X>-<first 8 of requestId>.mp4" "<result URL>"`, then probe it, and write the local path, measured duration and `cost` to the manifest. From here on the local file is the take; the URL is never opened again. Show the result by naming the local path and the measured duration.

### P4 · Look at frames

From the local file, with ffmpeg, never a browser: the scan strip, full-res grabs and zoom crops in `references/assembly.md` → Frames. Open the stills yourself with the Read tool and report by timestamp and rule.

### P5 · Frame-QC checklist

Product fidelity and label legibility (front of pack, readable text or say it is unreadable; products that share a shape are verified by colour and label per shot) · **label-out at every moment the pack is in frame** (rule 3: scrub pack beats frame by frame) · **scale against the hand and any other pack in frame** (rule 4) · **wardrobe and accessories blank** (rule 5: zoom on garments, bands, jewelry) · hands and arms (anatomy, limbs on the correct sides) · jewelry · hair continuity · wardrobe as specified · unwanted text · every planned beat present. With one take, identity and duration ride together: a failure on identity re-rolls the whole take; a defect confined to one beat is Stage 4b.

### P6 · Assemble

Editing is free; only generation costs credits. Assemble every take as soon as it is downloaded and QC'd, pass or fail. Never stop to ask whether to cut a flawed take together: make the best cut the footage allows (trim around defects where you can) and present the QC concerns alongside the finished edit. Recipes, the caption builder and the fingerprint rule are in `references/assembly.md`. Finals are delivered as local files in the campaign folder and nowhere else; they never go back into Enhancor.

### P7 · Reformat for the feed

`bash "$BIN/reformat.sh" "<clean master>" "<caption json>[,<second json>]" "<output>" [--size WxH] [--x F --y F] [--mode pad] [--crf N] [--audio strip]`. The size defaults to 1100x1080; pass `--size` when `brand.md` sets a different `feed format`. Always from the `(no captions)` master, with the same caption JSON(s) the approved 9:16 cut was burned with; the script writes a feed copy of each (`…-1100x1080.json`, sizes and margins rescaled), burns them, and refuses to overwrite. Check framing first with `--preview <dir>` (four stills, no encode) and open the stills. Recipe and framing rules: `references/assembly.md` → Feed reformat.

---

# Route A — new template from a reference reel

## Stage 1 — Short intake (no research)

**Research is banned.** This skill never browses the web, opens the brand's site, searches ad libraries, or reads anything beyond `brand.md`, the playbooks it lists, and what the user gives it in this conversation. If a script needs a fact the profile does not cover, ask in one line.

Ask these as one short block and wait:

1. **"Which product is this reel for?"** (from the `brand.md` products; skip if only one)
2. **"Send the reference reel you want to adapt."** A file or a link.
3. **"What should this reel highlight?"** The benefit, angle or moment they want front and centre.

As soon as the reference arrives, one follow-up: **"Are there any specific elements that are key to keep in the final prompt?"** Record the answers in `run-state.md` and go to Stage 2.

## Stage 2 — Local reference breakdown

Work only on the reference the user supplied. If several arrive, let the user pick one. Preserve source footage; write derivatives to `breakdown/<ref-id>/`.

**A. Measurement, with `analyze.sh` (P1).** It writes the probe, two cut-candidate lists (0.30 hard cuts, 0.08 broader changes), contact sheets, a 12-still scan strip, the audio, loudness, and a transcript when whisper is installed, plus `measurements.md` that summarises all of it with the cell→time formula. Segments of ≤30 s preferred; if the user asks for the whole of a longer video, cover every segment, never silently the first 30 s.

**B. Watching and listening, by you.** Open every contact sheet and the scan strip with the Read tool. Pull full-res frames around ambiguous cuts, text, gestures and setup changes (`measurements.md` prints the command). Read `transcript.srt` and check it against what the frames show; mark uncertain words `[?]`. If there is no transcript (no whisper, or no speech), say so and ask the user for the words only if the words matter to the adaptation. Sheets alone do not justify frame-accurate timing claims; cut lists are heuristics (flashes overcount, similar-colour cuts get missed), so count confirmed cuts separately from candidates; shots = confirmed internal cuts + 1.

Write `breakdown/<ref-id>/breakdown.md` with the eleven sections in `references/breakdown-template.md`. Keep it tight: working evidence, not a deliverable. Show the short version (specs, shot table, what carries the reel) and say you are moving to the preview; do not re-ask what to adapt.

(Faithful recreation of the source instead of adaptation is a separate request: keep authorized dialogue exact, exclude overlays, describe objects and positions concretely, match the real visual style.)

---

# Route B — saved template

## Stage 1b — Pick a template

List every file in `$UGC_LIBRARY/templates/` as a short chooser: name, one line on what it does, product, length, approval date, newest first. If only one exists, still show it and confirm. Once picked, take its prompt block as the working base, verbatim, say in one line what it is and what it costs to run, then go to Stage 2b. **Skip Stage 2 entirely**: a saved template is proven evidence; there is no reference to break down.

## Stage 2b — One tweak question

Ask exactly one open question and wait for a typed answer:

> **"Want to tweak any variables for this template run?"**

No option lists, no field enumeration, no per-field follow-ups. A blank or "no" means run the frozen prompt exactly as saved. Then apply what they said under this discipline. **A saved template is a winner: change the named thing and nothing else.**

- **Copy, don't rewrite.** Every line the change does not touch is carried across verbatim. Never re-word, tighten, reorder or "improve" untouched text.
- **Swap at the same grain.** A replacement is written at the same specificity and sentence shape as what it replaces.
- **Hold the skeleton fixed.** Beat count, timings, duration, camera language, framing, lighting, grade and pacing stay as saved unless the user changed that specific thing.
- **Follow the consequences, minimally.** A swap implies a few dependent edits; make exactly those and list them.
- **Keep the look when the subject changes.** Wardrobe, light, grade and camera belong to the template, not the character.
- **Show a diff, not a document.** Before → after lines plus the dependent edits.
- **Same length, same credits.** If a request would change duration or cost, say so and get a decision first.

Record the slug and the typed tweak in `run-state.md`, then Stage 3.

---

# Route C — new template from hand-written beats

## Stage 1c — Beats intake

If `$UGC_LIBRARY/templates/` holds fewer than three approved templates, say so once in one line (the recommended path is references first, because approved templates are what teach the prompt style) and continue if the user wants to.

Ask as one block and wait:

1. **"Which product?"** (skip if only one)
2. **"Paste your beats."** A numbered list in their own words: what happens, roughly in order, with any timings, setting, who she is, and anything that must be in the frame. Rough is fine.
3. **"What should this reel highlight?"**

Then read the two or three saved templates closest to the request (same product, similar setting or structure) as **style exemplars**: the subject-block shape, the prop line with the scale anchor, the light and look lines, the beat phrasing. Write the new master prompt in that established style under the Prompt-writing rules, keeping the user's beats as the spine: every beat they wrote appears, in their order, with its shot type added. Do not add beats they did not write except a product beat if the product must be in frame and they forgot it (say so). Record the beats in `run-state.md` and go to Stage 3.

---

## Stage 3 — Editable ad preview

Route A builds the plan from the Stage 1 answers and the breakdown: the highlight the user named leads, and every must-keep element appears in the master prompt. Route B builds it from the template plus the Stage 2b diff. Route C builds it from the beats plus the exemplar style. Match the reference's (or template's) **measured duration** and structure unless the user says otherwise. Pull packshot URLs for the products in the ad from `brand.md` (staging local ones with P1b) before assigning them to `images`.

**Plan (`production/YYYYMMDD - Hook vX - plan.md`)**: adaptation table (source beat/time → narrative function → retained mechanism → new product/message → evidence; Route C: beat → shot type → what the frame holds), audience hypothesis, the playbook concept it draws on (one line, or none), exact new on-screen copy written under **Caption copywriting** (humanizer pass applied if on), ordered beats with durations, action, camera, lighting, product visibility. Every claim passes `brand.md`; ⚑ lines listed under "First-person lines needing approval". Route B: the plan is the diff plus the caption table.

**Master prompt (`production/YYYYMMDD - Hook vX - master prompt.md`)**, sections:
1. Duration, aspect, observed style (phone/UGC realism only when the reference is phone/UGC).
2. **Product-image attachment map**: each packshot URL in `images` and what it governs (shape, cap, label, materials, colour). A product image sets identity; it is not automatically the first frame.
3. Scene, subject, wardrobe, object positions, lighting, camera behaviour.
4. Ordered, timed action beats, each opening with its shot type, written under the prompt-writing rules. One continuous take: the camera reframes by moving, it does not cut.
5. Audio: none wanted. "No speech or dialogue, her mouth stays closed."
6. Continuity: product, character, wardrobe, environment, restated in full.
7. What the frame holds, as positive description, with prohibitions kept to captions, other brands' logos and back-of-pack text.

Use `multi_reference` with the packshot(s) whenever a product is in shot, `text_to_video` otherwise. Never upload competitor footage as a generation reference.

**Cost line**: `bash "$ENH" cost <duration>`. Show duration, resolution, credits and dollars.

Show the **full** preview (on-screen copy, beats, master prompt, attachment map, cost), labelled with a version and the file name it will produce, and say:
> "Tell me any edits. When you're happy with this version, say **generate**."

Edits are not approval. Revise, bump the version, record it. **No paid calls during preview.**

## Stage 4 — Generation

"Generate" approves **only the currently shown version and its costed job.** Anything beyond it (retries, re-rolls, extra variants) needs a new costed decision.

1. **Submit**: P2 with the master prompt verbatim. Manifest first, then poll.
2. **Wait and fetch**: P3. On resume, poll the ids in the manifest instead of resubmitting.
3. **QC on frames, not prompts**: P4 against P5. Findings never hold up the edit; they ride alongside it.
4. **Assemble, always, without asking**: P6. Trim around defects, trim the settle, add the jump cuts the plan calls for, burn captions, write the captioned cut **and** the clean no-caption master to the campaign root, report measured duration against target. Re-captioning and retiming are free; never regenerate video for copy changes.
5. **Report**: playable final(s), the raw take, manifest, credits charged, measured duration, QC concerns by timestamp with what the edit already worked around. Paid repairs (4b) are offered as costed options after the cut is delivered. End with one line: "Tell me which cuts are approved for testing and I'll make the 1100x1080 versions and file them." Update run-state. **Never publish or post.**

## Stage 4b — Segment repair (patching one beat)

When the user says a beat is wrong, repair that shot only; never re-run the whole take for one bad beat. Needs file staging (`UGC_UPLOAD` ≠ none); if it is off, say so and offer the edit-around instead.

1. **Find the shot's boundaries** with the cut-detection line (assembly.md → Frames) on the downloaded take; open frames to confirm what is in the shot.
2. **Pick anchors from verified-clean frames of OTHER shots.** Never anchor on the broken shot (its frames carry the defect). Verify every candidate zoomed in at full resolution and reject anything mid-motion, water-obscured or distorted; say which you rejected and why. Choose two: one that carries the **place**, one that carries the **person**. Stage them with P1b.
3. **Pass them as `images` in a `multi_reference` job**, never as first/last frames (those force the pose and its errors).
4. **Strip the direction to the action**: one plain sentence, plus the look line and the no-text line. The anchors carry everything else.
5. **Generate at the model's minimum duration** (4 s, `bash "$ENH" cost 4`), whatever the hole's length; take the window you need in assembly.
6. **QC the patch on frames**, then cut it in on the existing hard cuts as its own segment. Captions retime for free.
7. **Record it** in the manifest: replaced span, anchor times and URLs, patch id, credits, QC findings.

**Harvest anchors once per take.** When a take is approved, pull two to four verified-clean stills (wide/place, mid, identity), confirm them zoomed, stage them if staging is on, and record times and URLs in run-state and the manifest. Anchors belong to the take, not the template.

## Stage 5 — Save the template

**Routes A and C only.** A Route B run never reaches this stage: do not offer, do not ask, do not mention it. Tweaked re-runs and caption variants are outputs, not templates.

**Trigger: the user approves the final output** (not delivery, not a QC pass). Approval for testing counts: run Stage 6 first, then ask once:

> "Want me to save this as a reusable template?"

If yes, write `$UGC_LIBRARY/templates/<slug>.md`:

```
# <Name>

<product> · <duration> s · <resolution> · <aspect> · Seedance 2.5 on Enhancor · <mode, and which packshots in images> · about <credits> credits (≈ $<x>) · approved <YYYY-MM-DD> (Enhancor job <id>) · <reference reel adapted | written from beats>

<Two or three lines on what the reel does and why it worked, including anything cut or changed in assembly.>

```<the complete approved prompt, verbatim, the exact string that was submitted>```
```

Nothing else goes in: no variable lists, no swappable-field inventories, no caption banks, no anchor ids. Packshots are referenced from `brand.md`, never copied into a template. Never rewrite or overwrite an existing template. Say the template is saved once the file exists, and note the count now in the library.

---

# Route D — caption variants of existing footage

Real footage the user already has (a creator clip, a past ad, a phone video, b-roll), re-cut into several caption variants for testing. Nothing is generated and nothing is spent. Every rule under **Caption copywriting** applies unchanged; the product rules apply to what is already in the frame.

## Stage 1d — Footage intake

Ask as one block and wait:

1. **"Which product is this for?"** (skip if only one)
2. **"Send the video."** A file, a folder of clips or a link. Several clips: each one is its own set of variants; ask which goes first, or do all in turn.
3. **"What should the variants test?"** Hooks, angles, formats, or "your pick". And how many (default **four**).

Record the answers and the source path in `run-state.md` and go to Stage 2d. Do not ask about audio, text or rights yet; Stage 2d shows which of those questions apply.

## Stage 2d — Footage check

Run P1 on the clip into `breakdown/<clip-id>/` and open the contact sheets and scan strip yourself. This is not the eleven-section adaptation breakdown; write nothing beyond `measurements.md`. Show at most six lines: duration, size and aspect, shot count, a timed beat list (the timeline the captions get pinned to), where the product is in frame and when its front reads, and any speech, music or on-screen text already in it.

Then ask, in one message, only the questions that apply:

- **Text already burned in** (an old caption, a watermark, a sticker): "It already has text at <t>. Cover it with boxed captions, crop past it, or do you have a clean copy?"
- **Speech or music in the track**: "Keep the original audio, or strip it?" Default strip (house rule: silent, captions carry the script). If kept, no caption may contradict what is said.
- **A real person on screen who is not the user**: "Is Grace cleared to run this clip in paid ads?" And because captions put words in a real person's mouth, every line claiming her own use or result gets ⚑ with an alternative, whatever the brand's testimonial policy says (that policy covers AI creators).
- **Anything on `brand.md`'s Never-in-frame list** (the old bag, the purple label): say where, and stop for a decision. Do not caption around it silently.
- **A dead opening or a clip longer than the idea**: propose the trim in seconds.

## Stage 3d — Caption variant sheet

Write `production/YYYYMMDD - Hook vX - caption variants.md`: one line on the footage and its beat timeline, the playbook concept it draws on (or none), the shared body captions once, then per variant its letter, its format (static POV, you hate / but now, or the full arc, by length), the hook or angle it tests in one line, and its caption table (start, end, top/bottom, text) timed to the beats actually in the footage.

- **Default design: a hook test over a fixed body.** Every variant shares the same captions after the hook (same text, same timing); only the hook caption(s) change, so a result can be read off the `h-` tag alone. The hooks must genuinely differ in approach (direct opener, pain, list, POV, curiosity), not be rewordings of one line. Pull from `brand.md` → Hooks to try and the playbooks' hook banks where a hook suits the footage. Varying the body, angle or format instead is a different test: do it only when the user asks, and say which field it changes.
- All the caption rules hold: the under-10 s count, a hook on screen by 0.3 s, never end on a feature, the claims lists, ⚑ lines, the humanizer pass if it is on.
- Name each file it will produce (lead variant unsuffixed, then `(variant B)`, …).

Show the whole sheet, labelled with its version, and say:
> "Tell me any edits or drop any variant. When it's right, say **render**."

Edits are not approval. Revise, bump the version, record it. There is no cost line; rendering is free.

## Stage 4d — Render the variants

1. **Clean master.** Trim per Stage 2d and normalise to 9:16 with P7, captions `none`: `--size 1080x1920` when the source is at least 1080 wide, `--size 720x1280` otherwise, `--audio strip` unless they chose to keep it. A source that is not 9:16 gets the P7 framing preview first. Save it as `YYYYMMDD - Hook vX (no captions).mp4` at the campaign root.
2. **One caption JSON per variant**, `production/clips/caps-<clip-id>-v<X>-<letter>.json`, with `play_res` set to the master's size (house sizes scale with it: 56/60/64 at 720 wide is 84/90/96 at 1080).
3. **Burn each variant** from the master with the captioned-cut recipe in `references/assembly.md` (keep `-c:a aac` instead of `-an` if the audio stays). Apply the fingerprint rule across the set: rotate CRF and caption size, and cut each variant's end by a different 0–0.3 s.
4. **Check the frames** (P4) at each variant's caption moments: captions clear of faces, of the pack's front at the product moment, and of any text left in the footage. Fix and re-cut before showing.
5. **Report**: the files, their durations, one line per variant on what it tests. Older versions of this clip's variants move to `Previous versions/`. End with: "Which of these are approved for testing?"

---

# Stage 6 — Approved for testing (every route)

**Trigger: the user names the cuts approved for testing** ("A and C are good to test", "approve all three"). Approval is per file: unnamed variants are left alone. The only question this stage asks is the one-time names table in step 1 (plus the landing page, once per campaign, if it is not already recorded).

1. **Ad names, confirmed once.** Read the naming sheet's glossary fresh and build two ad names per approved cut (`sz-9x16` and `sz-1100x1080`) under `references/ad-naming.md`, using `brand.md` → Ad naming for the fixed fields. Show one table: file, full ad name, and any new glossary values needed (new hooks, mostly). Wait for OK; that OK covers the names and the sheet write. Record the names in `run-state.md`.
2. **Find each approved cut's sources**: its `(no captions)` master and the caption JSON(s) it was burned with, from `run-state.md` and `production/clips/`. If a caption file cannot be found, say which and stop for that cut; never re-type captions from the video.
3. **Frame once per master** (variants of one take share it): `--preview production/clips/feed-preview-v<X>` and open the four stills. The crop must hold the subject's face and hands and, at the product moment, the pack's printed front. Move `--y` (smaller keeps the top: 0.3 holds a head in a tall frame) and preview again; if no crop window holds what matters, use `--mode pad`. State the choice in one line and record it in `run-state.md`.
4. **Encode each approved cut** with P7 into `Approved for testing/`, saved under its `sz-1100x1080` ad name (filesystem-safe, per `references/ad-naming.md`). Rotate `--crf 18/19/20` across the set.
5. **QC each feed cut** on two or three stills at caption moments: every line inside the frame, at most two lines a caption (the static POV may run to three), clear of faces and of the pack's front. A feed cut that fails before it has been shown to the user is a working file: delete it, adjust (`--cap-size`, `--top-margin`, or `"box": true` in the source JSON's feed copy) and encode again.
6. **Copy each approved 9:16 cut** into `Approved for testing/` under its `sz-9x16` ad name (copy, not move: the campaign root keeps its working-named finals). Write `Approved for testing/ad names.csv` (`file,ad name`), adding to it if it exists. The folder is then the complete upload set, two files per approved variant.
7. **Log to the naming sheet** (`references/ad-naming.md` → Logging): new glossary values first, then one generator row per file, then read the computed names back and check they match. No Sheets connector in the session: say so, and give the rows to paste.
8. **Report** the upload set as a short table: variant, what it tests, the two files, duration, and whether the sheet names matched. Update `run-state.md`. Files already in `Approved for testing/` from earlier approvals stay where they are even when a newer version exists; they may be live in a test. **Never upload, post or publish.**

Then, for Routes A and C only, Stage 5's template question.

## Ground rules

- Disclose missing tools, logins or evidence plainly; never claim a step ran when it did not.
- Don't make the user run commands beyond `setup-key` (which must be theirs, for the hidden input), open workflow files or manage stages.
- No independent research, ever. Ask the user instead. The naming sheet linked in `brand.md` is the one outside file the skill reads (Stage 6), and the only one it writes to.
- Never loop paid retries. Never install anything without a yes.
- One transport (Plumbing). A failed step is reported with its error, not routed around through a browser tab or another provider.
- When reusing a template, the burden of proof is on every change, not on keeping things the same.
- The three gates stay: plan approval before any paid call · character verified zoomed-in before anything is built on it · frame QC before delivery. Route D and Stage 6 make no paid calls, but frame QC before delivery still holds, and Stage 6 checks framing on stills before it encodes.

*Adapted from Miko's Video Ad Stack and Second-by-Second Video Breakdown SOP.*
