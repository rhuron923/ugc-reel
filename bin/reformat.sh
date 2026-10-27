#!/usr/bin/env bash
# reformat.sh — re-cut an approved reel for the feed size (default 1100x1080) and re-burn its captions at that size.
#
#   reformat.sh <clean master.mp4> <captions.json[,more.json] | none> <output.mp4> [options]
#   reformat.sh <clean master.mp4> none --preview <dir> [options]      # framing stills only, no encode
#
# Options:
#   --size WxH        output frame (default $UGC_FEED_SIZE, else 1100x1080)
#   --mode crop|pad   crop: fill the frame and crop (default). pad: whole frame fitted over a blurred copy of itself
#   --x F --y F       crop position, 0..1 (0 = left/top edge, 0.5 = centre, 1 = right/bottom edge). Default 0.5 / 0.5
#   --start S --end E trim the master first (seconds), e.g. a dead opening
#   --crf N           18 / 19 / 20, varied between exports (fingerprint rule). Default 19
#   --audio keep|strip  keep the master's audio track if it has one (default), or drop it
#   --cap-size N --top-margin N --bottom-margin N   override the derived feed caption layout
#
# Always reformat from the CLEAN master, never from a captioned cut: burned-in 9:16 captions would be cropped. The
# caption JSON is the one the approved 9:16 cut was burned with; this script writes a feed copy of it beside the
# output's working files (play_res set to the new size, size and margins rescaled) and burns that.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/_platform.sh"
eval "$(bash "$HERE/doctor.sh" --env)"
[ -n "$FF" ] || { echo "reformat.sh: no ffmpeg with libass found; run doctor.sh" >&2; exit 1; }

SRC="${1:-}"; CAPS="${2:-}"
[ -n "$SRC" ] && [ -n "$CAPS" ] || { sed -n '2,15p' "$0"; exit 1; }
shift 2
OUTF=""; case "${1:-}" in --*|"") ;; *) OUTF="$1"; shift;; esac
SIZE="${UGC_FEED_SIZE:-1100x1080}"; MODE=crop; X=0.5; Y=0.5; CRF=19; AUDIO=keep; PREVIEW=""
CAP_SIZE=""; TOP=""; BOTTOM=""; TRIM=()
while [ $# -gt 0 ]; do
  case "$1" in
    --size) SIZE="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --x) X="$2"; shift 2;;
    --y) Y="$2"; shift 2;;
    --crf) CRF="$2"; shift 2;;
    --start) TRIM+=(-ss "$2"); shift 2;;
    --end) TRIM+=(-to "$2"); shift 2;;
    --audio) AUDIO="$2"; shift 2;;
    --preview) PREVIEW="$2"; shift 2;;
    --cap-size) CAP_SIZE="$2"; shift 2;;
    --top-margin) TOP="$2"; shift 2;;
    --bottom-margin) BOTTOM="$2"; shift 2;;
    *) echo "reformat.sh: unknown option $1" >&2; exit 1;;
  esac
done
[ -f "$SRC" ] || { echo "reformat.sh: no such file: $SRC" >&2; exit 1; }
case "$SIZE" in *x*) W="${SIZE%x*}"; H="${SIZE#*x}";; *) echo "reformat.sh: --size must be WxH" >&2; exit 1;; esac
case "$MODE" in crop|pad) ;; *) echo "reformat.sh: --mode is crop or pad" >&2; exit 1;; esac
[ -n "$PREVIEW" ] || [ -n "$OUTF" ] || { echo "reformat.sh: give an output file or --preview <dir>" >&2; exit 1; }

if [ "$MODE" = crop ]; then
  VF="scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H:(iw-ow)*$X:(ih-oh)*$Y,setsar=1"
else
  VF="split[a][b];[a]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,boxblur=24:4[bg];[b]scale=$W:$H:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1"
fi
DUR="$("$FP" -v error -show_entries format=duration -of default=nw=1:nk=1 "$SRC" | nocr)"

# Framing check: four stills of the reformatted frame, for Claude to open before anything is encoded.
if [ -n "$PREVIEW" ]; then
  mkdir -p "$PREVIEW"
  for i in 0 1 2 3; do
    t=$(awk -v d="$DUR" -v i="$i" 'BEGIN{printf "%.2f", d*(i*2+1)/8}')
    "$FF" -y -v error -ss "$t" -i "$SRC" -frames:v 1 -vf "$VF,scale=550:-2" -q:v 3 "$PREVIEW/feed-preview_${i}_${t}s.jpg"
  done
  ls "$PREVIEW"/feed-preview_*.jpg
  exit 0
fi

SRC_ABS="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"
OUT_DIR="$(cd "$(dirname "$OUTF")" && pwd)"; OUT_ABS="$OUT_DIR/$(basename "$OUTF")"
# Native Windows ffmpeg gets C:/… paths: Git Bash skips its automatic /c/… conversion for an argument containing a
# quote character (a folder named "don't use" broke it).
if is_windows; then SRC_ABS="$(cygpath -m "$SRC_ABS")"; OUT_ABS="$(cygpath -m "$OUT_ABS")"; fi
[ -e "$OUT_ABS" ] && { echo "reformat.sh: $OUT_ABS already exists; never overwrite, pick a new name" >&2; exit 1; }
if [ "$AUDIO" = keep ]; then AARGS=(-map 0:v:0 -map "0:a:0?" -c:a aac -b:a 160k); else AARGS=(-map 0:v:0 -an); fi

if [ "$CAPS" = none ]; then
  "$FF" -y -v error ${TRIM[@]+"${TRIM[@]}"} -i "$SRC_ABS" -vf "$VF" -c:v libx264 -preset medium -crf "$CRF" -pix_fmt yuv420p -r 30 "${AARGS[@]}" "$OUT_ABS"
else
  [ -n "$PY" ] || { echo "reformat.sh: no working Python 3 for the caption builder" >&2; exit 1; }
  # Several caption files (comma-separated) burn in order, the way a 9:16 cut with a hook layer and a label layer was.
  IFS=, read -r -a CAPLIST <<< "$CAPS"
  CAP_DIR="$(cd "$(dirname "${CAPLIST[0]}")" && pwd)"; SUBS=""
  for c in "${CAPLIST[@]}"; do
    [ -f "$c" ] || { echo "reformat.sh: no such caption file: $c" >&2; exit 1; }
    BASE="$(basename "$c" .json)-${W}x${H}"
    # Feed caption layout: sizes scale from the 9:16 spec (house 56/60/64 at 720 wide → about 67/72/77), margins drop
    # to feed values (no TikTok UI to clear) and keep the spec's own jitter so variants still differ.
    "$PY" - "$c" "$CAP_DIR/$BASE.json" "$W" "$H" "$CAP_SIZE" "$TOP" "$BOTTOM" <<'PYEOF'
import json, sys
src, dst, w, h, size, top, bottom = sys.argv[1:8]
spec = json.load(open(src, encoding="utf-8"))
sw, sh = spec.get("play_res", [720, 1280])
s = int(spec.get("size", 60)) * 720 / float(sw)
spec["play_res"] = [int(w), int(h)]
spec["size"] = int(size) if size else round(s * 1.2)
spec["top_margin"] = int(top) if top else 70 + (int(spec.get("top_margin", 180) * 1280 / float(sh)) - 180) // 3
spec["bottom_margin"] = int(bottom) if bottom else 80
json.dump(spec, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PYEOF
    "$PY" "$HERE/make-ass.py" "$CAP_DIR/$BASE.json" > "$CAP_DIR/$BASE.ass"
    SUBS="$SUBS,subtitles=$BASE.ass"; echo "captions: $CAP_DIR/$BASE.json"
  done
  # subtitles= gets bare filenames from inside the caption folder: a Windows drive colon breaks the filter's parser.
  ( cd "$CAP_DIR" && "$FF" -y -v error ${TRIM[@]+"${TRIM[@]}"} -i "$SRC_ABS" -vf "$VF$SUBS" \
      -c:v libx264 -preset medium -crf "$CRF" -pix_fmt yuv420p -r 30 "${AARGS[@]}" "$OUT_ABS" )
fi

OW="$("$FP" -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$OUT_ABS" | nocr)"
OH="$("$FP" -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$OUT_ABS" | nocr)"
OD="$("$FP" -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUT_ABS" | nocr)"
echo "wrote: $OUT_ABS · ${OW}x${OH} · $(awk -v d="$OD" 'BEGIN{printf "%.2f", d}') s · mode $MODE (x $X, y $Y) · crf $CRF · audio $AUDIO"
