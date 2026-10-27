#!/usr/bin/env bash
# doctor.sh — check (and, on request, install) the local tools ugc-reel needs. No network unless --install.
#
#   doctor.sh            report each tool as OK / MISSING, print the install commands, exit 1 if anything required is missing
#   doctor.sh --install  Mac with Homebrew: brew install the missing tools; Windows (Git Bash): winget install them and fetch
#                        whisper.cpp; both also download the whisper model. Linux: print only
#   doctor.sh --env      print shell assignments for FF / FP / PY / WHISPER / WHISPER_MODEL (eval-able), nothing else
#
# Required: ffmpeg built with libass (burns captions), ffprobe, python3, curl. Recommended: yt-dlp (pasted reel links),
# whisper-cli + a ggml model (local transcription), jq, fc-list. Optional: aws (only for UGC_UPLOAD=s3).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/_platform.sh"
USER_CONFIG="$HOME/.config/ugc-reel/config.env"
# shellcheck disable=SC1090,SC1091
{ set -a; [ -f "$HERE/config.env" ] && . "$HERE/config.env"; [ -f "$USER_CONFIG" ] && . "$USER_CONFIG"; set +a; }
WHISPER_MODEL="${UGC_WHISPER_MODEL:-$HOME/.config/ugc-reel/models/ggml-base.bin}"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$(basename "$WHISPER_MODEL")"
# whisper.cpp's versioned releases (v1.x) carry no Windows binaries; the build-tag releases (bNNNN) do, so the newest
# release with this asset is looked up at install time.
WHISPER_RELEASES_API="https://api.github.com/repos/ggml-org/whisper.cpp/releases?per_page=20"
WHISPER_ASSET="whisper-bin-x64.zip"
WHISPER_DIR="$HOME/.config/ugc-reel/whisper"
MODE="${1:-report}"

find_ffmpeg() {
  local c
  for c in /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg /usr/local/opt/ffmpeg-full/bin/ffmpeg ffmpeg /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg /usr/bin/ffmpeg; do
    command -v "$c" >/dev/null 2>&1 || continue
    "$c" -hide_banner -buildconf 2>/dev/null | grep -q -- '--enable-libass' && { command -v "$c"; return 0; }
  done
  return 1
}

FF="$(find_ffmpeg || true)"
FP=""; [ -n "$FF" ] && FP="$(dirname "$FF")/ffprobe" && command -v "$FP" >/dev/null 2>&1 || FP="$(command -v ffprobe || true)"
WHISPER="$(command -v whisper-cli || command -v whisper-cpp || true)"

if [ "$MODE" = "--env" ]; then
  printf 'FF=%q\nFP=%q\nPY=%q\nWHISPER=%q\nWHISPER_MODEL=%q\n' "$FF" "$FP" "$PY" "$WHISPER" "$WHISPER_MODEL"
  exit 0
fi

# Each missing tool is recorded under its package name for the platform's installer.
missing_pkgs=(); missing_required=0; need_model=0; need_whisper_zip=0
pkg() {  # pkg <brew name> <winget id>
  if is_windows; then [ -n "$2" ] && missing_pkgs+=("$2"); else missing_pkgs+=("$1"); fi
}
ok()   { printf '  OK       %-22s %s\n' "$1" "$2"; }
miss() { printf '  MISSING  %-22s %s\n' "$1" "$2"; }

has_montserrat() {
  if command -v fc-list >/dev/null; then fc-list 2>/dev/null | grep -qi montserrat; return; fi
  if is_windows; then
    ls /c/Windows/Fonts "$(cygpath -u "${LOCALAPPDATA:-}")/Microsoft/Windows/Fonts" 2>/dev/null | grep -qi montserrat; return
  fi
  return 1
}

echo "ugc-reel doctor ($(uname -s), $UGC_OS)"
if [ -n "$FF" ]; then ok "ffmpeg (libass)" "$FF"
else
  if is_mac; then miss "ffmpeg (libass)" "needed to burn captions; the plain Homebrew ffmpeg lacks libass"
  else miss "ffmpeg (libass)" "needed to burn captions"; fi
  pkg ffmpeg-full Gyan.FFmpeg; missing_required=1
fi
if [ -n "$FP" ]; then ok "ffprobe" "$FP"; else miss "ffprobe" "comes with ffmpeg"; missing_required=1; fi
if [ -n "$PY" ]; then ok "python3" "$PY"
else
  if is_windows; then miss "python3" "needed by the helpers (the python3 in WindowsApps is only a Microsoft Store stub)"
  else miss "python3" "needed by the helpers"; fi
  pkg python3 Python.Python.3.12; missing_required=1
fi
if command -v curl >/dev/null; then ok "curl" "$(command -v curl)"; else miss "curl" "needed to talk to Enhancor"; missing_required=1; fi
if command -v yt-dlp >/dev/null; then ok "yt-dlp" "$(command -v yt-dlp)"; else miss "yt-dlp" "downloads pasted TikTok / Reel / Short links (otherwise send the file)"; pkg yt-dlp yt-dlp.yt-dlp; fi
if [ -n "$WHISPER" ]; then ok "whisper-cli" "$WHISPER"
else
  miss "whisper-cli" "local transcription of the reference's speech (whisper.cpp)"
  if is_windows; then need_whisper_zip=1; else pkg whisper-cpp ""; fi
fi
if [ -f "$WHISPER_MODEL" ]; then ok "whisper model" "$WHISPER_MODEL"; else miss "whisper model" "$(basename "$WHISPER_MODEL") (~150 MB) from $MODEL_URL"; need_model=1; fi
if command -v jq >/dev/null; then ok "jq" "$(command -v jq)"; else miss "jq" "handy for reading job JSON (optional)"; pkg jq jqlang.jq; fi
if has_montserrat; then ok "caption font" "Montserrat installed"; else ok "caption font" "Montserrat not installed; captions use Arial Bold (fine)"; fi
if [ "${UGC_UPLOAD:-none}" = "s3" ]; then
  if command -v aws >/dev/null; then ok "aws CLI" "$(command -v aws)"; else miss "aws CLI" "UGC_UPLOAD=s3 needs it"; pkg awscli Amazon.AWSCLI; fi
fi
if is_mac; then
  if command -v brew >/dev/null; then ok "Homebrew" "$(command -v brew)"; else miss "Homebrew" "install from https://brew.sh (asks for your Mac password, so that step is yours)"; fi
fi
if is_windows; then
  if command -v winget >/dev/null; then ok "winget" "$(command -v winget)"; else miss "winget" "install 'App Installer' from the Microsoft Store"; fi
fi

echo
if [ ${#missing_pkgs[@]} -eq 0 ] && [ "$need_model" -eq 0 ] && [ "$need_whisper_zip" -eq 0 ]; then
  echo "Everything is in place."
  exit 0
fi

echo "To fix:"
if [ ${#missing_pkgs[@]} -gt 0 ]; then
  if is_mac; then echo "  brew install ${missing_pkgs[*]}"
  elif is_windows; then for p in "${missing_pkgs[@]}"; do echo "  winget install -e --id $p --source winget"; done
  else echo "  Linux: install with your package manager, e.g.  sudo apt install ffmpeg yt-dlp jq python3   and build whisper.cpp from https://github.com/ggerganov/whisper.cpp (whisper-cli)"; fi
fi
if [ "$need_whisper_zip" -eq 1 ]; then
  echo "  whisper.cpp for Windows: unzip $WHISPER_ASSET from the newest https://github.com/ggml-org/whisper.cpp/releases build into $WHISPER_DIR (doctor.sh --install does this)"
fi
if [ "$need_model" -eq 1 ]; then
  echo "  mkdir -p \"$(dirname "$WHISPER_MODEL")\" && curl -L -o \"$WHISPER_MODEL\" \"$MODEL_URL\""
fi

install_whisper_windows() {
  local tmp zip found url
  url="$(curl -fsSL "$WHISPER_RELEASES_API" | grep -o "https://github.com/[^\"]*/$WHISPER_ASSET" | head -1)"
  [ -n "$url" ] || { echo "doctor: no $WHISPER_ASSET found in the recent whisper.cpp releases" >&2; return 1; }
  tmp="$(mktemp -d)"; zip="$tmp/whisper.zip"
  echo; echo "Downloading whisper.cpp ($url) to $WHISPER_DIR"
  curl -fL --retry 3 -o "$zip" "$url" || { echo "doctor: whisper.cpp download failed" >&2; rm -rf "$tmp"; return 1; }
  # Windows' own tar (bsdtar) unpacks zip files; Git Bash's GNU tar does not.
  /c/Windows/System32/tar.exe -xf "$(cygpath -w "$zip")" -C "$(cygpath -w "$tmp")" || { echo "doctor: could not unzip whisper.cpp" >&2; rm -rf "$tmp"; return 1; }
  found="$(find "$tmp" -iname 'whisper-cli.exe' | head -1)"
  [ -n "$found" ] || { echo "doctor: whisper-cli.exe not found in the download" >&2; rm -rf "$tmp"; return 1; }
  mkdir -p "$WHISPER_DIR" && cp -f "$(dirname "$found")"/* "$WHISPER_DIR"/
  rm -rf "$tmp"
}

if [ "$MODE" = "--install" ]; then
  if is_mac && command -v brew >/dev/null; then
    if [ ${#missing_pkgs[@]} -gt 0 ]; then echo; echo "Installing: brew install ${missing_pkgs[*]}"; brew install "${missing_pkgs[@]}" || { echo "doctor: brew install failed" >&2; exit 1; }; fi
  elif is_windows && command -v winget >/dev/null; then
    for p in "${missing_pkgs[@]}"; do
      echo; echo "Installing: winget install -e --id $p --source winget"
      winget install -e --id "$p" --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity \
        || echo "doctor: winget install $p did not complete (it may already be installed; the check below says)" >&2
    done
    if [ "$need_whisper_zip" -eq 1 ]; then install_whisper_windows || exit 1; fi
  else
    echo; echo "--install only runs on a Mac with Homebrew or Windows with winget; run the commands above yourself."
    exit 1
  fi
  if [ "$need_model" -eq 1 ]; then
    echo; echo "Downloading whisper model to $WHISPER_MODEL"
    mkdir -p "$(dirname "$WHISPER_MODEL")" && curl -fL --retry 3 -o "$WHISPER_MODEL" "$MODEL_URL" || { echo "doctor: model download failed" >&2; exit 1; }
  fi
  echo; exec bash "$0"
fi

[ "$missing_required" -eq 0 ] || exit 1
exit 0
