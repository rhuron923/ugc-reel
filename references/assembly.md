# Assembly recipes (P6)

Editing is free; only generation costs credits. Everything here runs on the user's machine with the libass ffmpeg the doctor found (`eval "$(bash "$BIN/doctor.sh" --env)"` gives `$FF`, `$FP` and `$PY`).

## Captions

Write `production/clips/caps-v<X>.json` and build the `.ass` with the bundled script:

```json
{
  "font": "Montserrat", "size": 60, "top_margin": 180, "bottom_margin": 320,
  "captions": [
    {"start": 0.30, "end": 2.60, "pos": "top", "text": "this is how i get ready\nfor a swim"},
    {"start": 4.80, "end": 7.60, "pos": "bottom", "text": "Product Name"}
  ]
}
```

```bash
"$PY" "$BIN/make-ass.py" production/clips/caps-v1.json > production/clips/caps-v1.ass
```

Use `"font": "Montserrat"` only if the doctor reports Montserrat installed (it checks `fc-list`, or the Windows font folders); otherwise `"Arial"` (Bold is on in the style). Never install fonts mid-run. Time captions to the **beats in the delivered footage** (from the scan strip), not the plan; generated timing drifts a second or two. The product-name caption sits at the bottom under the pack; everything else at the top. `"box": true` on a caption draws an opaque box behind it, which also covers stray text the model burned into a take.

## Cut and encode

From inside `production/clips/` (encode flags are spelled out in every command on purpose: zsh does not word-split an unquoted `$ENC`, so a flags-in-a-variable shortcut breaks):

```bash
VF="scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1"
# 1. segments: trim the opening settle (~1.0–1.6 s of drift on generated footage) and cut the jump cuts the plan calls for
$FF -y -v error -ss 1.2 -t 3.0 -i take.mp4 -vf "$VF" -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 -an p1.mp4
$FF -y -v error -ss 4.8 -i take.mp4 -vf "$VF" -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 -an p2.mp4
printf "file 'p1.mp4'\nfile 'p2.mp4'\n" > list.txt
# 2. clean silent master
$FF -y -v error -f concat -safe 0 -i list.txt -c copy "../../<YYYYMMDD - Hook vX> (no captions).mp4"
# 3. captioned cut
$FF -y -v error -i "../../<YYYYMMDD - Hook vX> (no captions).mp4" -vf "subtitles=caps-vX.ass" -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -r 30 -an "../../<YYYYMMDD - Hook vX>.mp4"
# 4. measure and report
$FP -v error -show_entries format=duration -of default=nw=1:nk=1 "../../<YYYYMMDD - Hook vX>.mp4"
```

A single-take reel with no jump cuts skips step 1: caption the take directly. For a different aspect, change the `scale`/`pad` numbers and `play_res` in the caption JSON. Speed a beat up with `-vf "setpts=PTS/1.5"` on that segment. Intermediate files (`p1.mp4`, `list.txt`, the `.ass`) stay in `production/clips/`; mention them, do not delete them.

## Fingerprint every export

Two reels that share a duration and an encode can be hashed as the same video by the platform, which quietly kills the second one's reach. So no two exports match: jitter each segment length by up to ±0.3 s, and vary the encode between cuts: CRF 18/19/20, caption size 56/60/64, top margin 170/180/195. Variants of one approved take especially.

## Feed reformat (P7, Stage 6)

`bin/reformat.sh` does the whole job; never hand-roll a crop of a captioned cut (the 9:16 captions would be cut off). From the campaign folder:

```bash
M="YYYYMMDD - Hook vX (no captions).mp4"
# 1. framing: four stills of the 1100x1080 crop, no encode; open them
bash "$BIN/reformat.sh" "$M" none --preview production/clips/feed-preview-vX
# 2. not right? move the window (0 = top, 1 = bottom) or fit the whole frame over a blurred fill, and preview again
bash "$BIN/reformat.sh" "$M" none --preview production/clips/feed-preview-vX --y 0.3
bash "$BIN/reformat.sh" "$M" none --preview production/clips/feed-preview-vX --mode pad
# 3. one encode per approved cut, with the caption JSON(s) that cut was burned with
mkdir -p "Approved for testing"
# file names are the ad names from Stage 6 step 1 (references/ad-naming.md); they differ only in sz-
bash "$BIN/reformat.sh" "$M" production/clips/caps-vX-B.json "Approved for testing/<ad name ... - sz-1100x1080>.mp4" --y 0.3 --crf 20
cp -n "YYYYMMDD - Hook vX (variant B).mp4" "Approved for testing/<ad name ... - sz-9x16>.mp4"
```

A cut burned with two caption layers takes both, comma-separated: `caps-v3-A-hook.json,caps-v3-A-labels.json`. The script writes the feed copies (`…-1100x1080.json/.ass`) next to the originals: size ×1.2 of the 720-wide size (60 → 72), top margin about 70, bottom 80, each spec's own jitter kept. Override with `--cap-size`, `--top-margin`, `--bottom-margin`. It keeps the master's audio if it has one (`--audio strip` drops it), trims with `--start`/`--end`, and refuses to overwrite an existing file.

Framing rules: crop is the default because it fills the feed frame. A 9:16 master loses a little over 40% of its height, so check the face, the hands and, at the product moment, the pack's printed front. Pad only when no crop window holds them; it keeps everything at the cost of blurred bands at the sides.

The same script normalises Route D footage to a 9:16 master (`--size 1080x1920` or `--size 720x1280`, captions `none`).

## Frames (P4)

```bash
# 12-still scan strip ($DUR from ffprobe)
for i in $(seq 0 11); do t=$(awk "BEGIN{printf \"%.2f\", $DUR*($i+0.5)/12}"); \
  $FF -y -v error -ss $t -i take.mp4 -frames:v 1 -vf scale=360:-2 -q:v 4 production/clips/scan_$(printf %02d $i).jpg; done
# full-res grab at a timestamp that matters (label beat, hands, a suspect frame)
$FF -y -v error -ss 5.20 -i take.mp4 -frames:v 1 -q:v 2 production/clips/qc_5.20.png
# zoom on a region: crop w:h:x:y then upscale
$FF -y -v error -ss 5.20 -i take.mp4 -frames:v 1 -vf "crop=300:400:210:500,scale=900:-2" production/clips/qc_5.20_label.png
# cut boundaries in a delivered take (info log level: -v error silences showinfo)
$FF -v info -i take.mp4 -vf "select='gt(scene,0.30)',showinfo" -f null - 2>&1 | grep -o 'pts_time:[0-9.]*'
```

Open the stills with the Read tool and report by timestamp and rule.
