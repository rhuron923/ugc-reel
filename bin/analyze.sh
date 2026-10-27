#!/usr/bin/env bash
# analyze.sh — local reference-reel analysis (no cloud analyzer). Measures, cuts, contact sheets, transcript.
#
#   analyze.sh <file-or-URL> <outdir> [--start S] [--end E] [--fps 3]
#
# Writes into <outdir>:
#   source.<ext>        the original (downloaded with yt-dlp for a link, copied for a file)
#   segment.mp4         the trimmed segment when --start/--end are given (otherwise a symlink to source)
#   probe.json          ffprobe output (streams + format)
#   cuts-030.txt        hard-cut candidates, scene threshold 0.30 (seconds, one per line)
#   cuts-008.txt        broader visual-change candidates, threshold 0.08
#   sheet_NN.jpg        contact sheets, 4x4 cells at --fps frames per second (cell -> time formula in measurements.md)
#   scan_NN.jpg         12 evenly spaced stills (quick overview)
#   audio.wav           16 kHz mono audio (for transcription)
#   transcript.srt/json when whisper-cli and a model are available
#   loudness.txt        ebur128 integrated loudness summary
#   measurements.md     everything above, summarised, for the breakdown
#
# Everything here is a measurement or a picture for Claude to look at. Cut lists are heuristics: flashes overcount,
# similar-colour cuts get missed. Confirm on frames before calling a timing frame-accurate.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/_platform.sh"
eval "$(bash "$HERE/doctor.sh" --env)"
[ -n "$FF" ] || { echo "analyze.sh: no ffmpeg with libass found; run doctor.sh" >&2; exit 1; }

SRC="${1:-}"; OUT="${2:-}"; [ -n "$SRC" ] && [ -n "$OUT" ] || { sed -n '2,5p' "$0"; exit 1; }
shift 2
START=""; END=""; FPS=3
while [ $# -gt 0 ]; do
  case "$1" in
    --start) START="$2"; shift 2;;
    --end) END="$2"; shift 2;;
    --fps) FPS="$2"; shift 2;;
    *) echo "analyze.sh: unknown option $1" >&2; exit 1;;
  esac
done
mkdir -p "$OUT"

# 1. get the file
case "$SRC" in
  http://*|https://*)
    command -v yt-dlp >/dev/null || { echo "analyze.sh: yt-dlp is not installed; ask for the file instead" >&2; exit 1; }
    yt-dlp -q --no-warnings -o "$OUT/source.%(ext)s" "$SRC" || { echo "analyze.sh: yt-dlp could not fetch that link; ask for the file" >&2; exit 1; };;
  *)
    [ -f "$SRC" ] || { echo "analyze.sh: no such file: $SRC" >&2; exit 1; }
    cp -n "$SRC" "$OUT/source.${SRC##*.}" 2>/dev/null || true;;
esac
SOURCE="$(ls "$OUT"/source.* 2>/dev/null | head -1)"; [ -n "$SOURCE" ] || { echo "analyze.sh: no source file landed in $OUT" >&2; exit 1; }

# 2. segment
SEG="$OUT/segment.mp4"
if [ -n "$START" ] || [ -n "$END" ]; then
  args=(); [ -n "$START" ] && args+=(-ss "$START"); [ -n "$END" ] && args+=(-to "$END")
  "$FF" -y -v error "${args[@]}" -i "$SOURCE" -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p -c:a aac "$SEG"
else
  # Git Bash cannot make real symlinks without extra Windows settings, so Windows gets a copy.
  if is_windows; then cp -f "$SOURCE" "$SEG"; else ln -sf "$(basename "$SOURCE")" "$SEG"; fi
fi
OFFSET="${START:-0}"

# 3. probe
"$FP" -v error -show_streams -show_format -of json "$SEG" > "$OUT/probe.json"
DUR="$("$FP" -v error -show_entries format=duration -of default=nw=1:nk=1 "$SEG" | nocr)"
W="$("$FP" -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$SEG" | nocr)"
H="$("$FP" -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$SEG" | nocr)"
FR="$("$FP" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$SEG" | nocr)"
HAS_AUDIO="$("$FP" -v error -select_streams a -show_entries stream=codec_type -of default=nw=1:nk=1 "$SEG" | nocr | head -1)"

# 4. cuts (info log level on purpose: -v error silences showinfo)
"$FF" -v info -i "$SEG" -vf "select='gt(scene,0.30)',showinfo" -f null - 2>&1 | grep -o 'pts_time:[0-9.]*' | cut -d: -f2 > "$OUT/cuts-030.txt" || true
"$FF" -v info -i "$SEG" -vf "select='gt(scene,0.08)',showinfo" -f null - 2>&1 | grep -o 'pts_time:[0-9.]*' | cut -d: -f2 > "$OUT/cuts-008.txt" || true

# 5. contact sheets + scan strip
"$FF" -y -v error -i "$SEG" -vf "fps=$FPS,scale=270:480:force_original_aspect_ratio=decrease,pad=270:480:(ow-iw)/2:(oh-ih)/2,tile=4x4:padding=4" -q:v 3 "$OUT/sheet_%02d.jpg"
for i in $(seq 0 11); do
  t=$(awk -v d="$DUR" -v i="$i" 'BEGIN{printf "%.2f", d*(i+0.5)/12}')
  "$FF" -y -v error -ss "$t" -i "$SEG" -frames:v 1 -vf scale=360:-2 -q:v 4 "$OUT/scan_$(printf %02d "$i").jpg"
done

# 6. audio: wav, loudness, transcript
TRANSCRIPT="not run"
if [ "$HAS_AUDIO" = "audio" ]; then
  "$FF" -y -v error -i "$SEG" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT/audio.wav"
  "$FF" -v info -i "$OUT/audio.wav" -af ebur128=framelog=verbose -f null - 2>&1 | grep -A4 'Integrated loudness' > "$OUT/loudness.txt" || true
  if [ -n "$WHISPER" ] && [ -f "$WHISPER_MODEL" ]; then
    "$WHISPER" -m "$WHISPER_MODEL" -f "$OUT/audio.wav" -l "${UGC_WHISPER_LANG:-auto}" -osrt -oj -of "$OUT/transcript" -np >/dev/null 2>&1 \
      && TRANSCRIPT="$OUT/transcript.srt" || TRANSCRIPT="whisper-cli failed (see audio.wav; transcribe by ear from the file if needed)"
  else
    TRANSCRIPT="skipped: whisper-cli or its model is missing (run doctor.sh --install). Words must come from the user or be marked unknown."
  fi
else
  TRANSCRIPT="no audio stream"
fi

# 7. measurements.md
N030="$(grep -c . "$OUT/cuts-030.txt" || true)"; N008="$(grep -c . "$OUT/cuts-008.txt" || true)"
STEP="$(awk -v d="$DUR" 'BEGIN{printf "%.2f", d/12}')"; DUR2="$(awk -v d="$DUR" 'BEGIN{printf "%.2f", d}')"
CELLS=16
{
  echo "# Measurements: $(basename "$SOURCE")"
  echo
  echo "- source: $SOURCE"
  echo "- segment: ${START:-0} to ${END:-end} (offset $OFFSET s added to every time below when mapping back to the source)"
  echo "- duration: ${DUR2} s · ${W}x${H} · ${FR} fps · audio: ${HAS_AUDIO:-none}"
  echo "- hard-cut candidates (scene > 0.30): $N030 → shots ≈ $((N030 + 1)) if all confirm. Times: $(paste -sd' ' "$OUT/cuts-030.txt")"
  echo "- change candidates (scene > 0.08): $N008. Times: $(paste -sd' ' "$OUT/cuts-008.txt")"
  echo "- contact sheets: $(ls "$OUT"/sheet_*.jpg | wc -l | tr -d ' ') at $FPS fps, 4x4 cells. Cell → time: ((sheet-1)*$CELLS + cell-1)/$FPS + $OFFSET. Padding cells are not frames."
  echo "- scan strip: scan_00..11.jpg every ${STEP} s (centre of each twelfth)"
  echo "- loudness: $(grep -m1 'I:' "$OUT/loudness.txt" 2>/dev/null | tr -s ' ' || echo 'n/a')"
  echo "- transcript: $TRANSCRIPT"
  echo
  echo "Open every sheet. Pull full-res frames around ambiguous cuts, text, gestures and setup changes with:"
  echo "  $FF -y -v error -ss <t> -i \"$SEG\" -frames:v 1 -q:v 2 \"$OUT/frame_<t>.png\""
} > "$OUT/measurements.md"
cat "$OUT/measurements.md"
