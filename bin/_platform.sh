# _platform.sh — sourced by the helpers. Smooths over macOS / Linux / Windows (Git Bash) differences. No output.
#
# Windows notes: the helpers run under Git Bash. Native Windows programs (ffmpeg, python, whisper-cli, aws) write
# CRLF line endings to pipes, so every captured value goes through nocr. The "python3" on a fresh Windows install is
# a Microsoft Store stub that prints a message and fails, so the interpreter is found by actually running it.

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) UGC_OS=windows;;
  Darwin) UGC_OS=mac;;
  *) UGC_OS=linux;;
esac
is_mac() { [ "$UGC_OS" = mac ]; }
is_windows() { [ "$UGC_OS" = windows ]; }

nocr() { tr -d '\r'; }

if is_windows; then
  # Where winget's portable tools, a winget Python and the doctor's whisper.cpp land. A shell started before an
  # install may not have them on PATH yet.
  _la="$(cygpath -u "${LOCALAPPDATA:-$USERPROFILE/AppData/Local}")"
  for _d in "$_la/Microsoft/WinGet/Links" "$HOME/.config/ugc-reel/whisper" "$_la"/Programs/Python/Python3*; do
    [ -d "$_d" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH";; esac
  done
  # winget's portable packages go on the user PATH as their own folders (Packages/<id>, or Packages/<id>/<build>/bin
  # for ffmpeg) when it cannot make links. Gyan's ffmpeg comes first so it wins over the yt-dlp ffmpeg build.
  for _d in "$_la"/Microsoft/WinGet/Packages/Gyan.FFmpeg*/*/bin "$_la"/Microsoft/WinGet/Packages/*; do
    [ -d "$_d" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$PATH:$_d";; esac
  done
  export PATH; unset _la _d
  # Windows Python defaults to cp1252 for pipes and files, which cannot print "≈" or read UTF-8 caption JSON.
  export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
fi

# find_python — prints the path of a working Python 3.7+ interpreter, or fails.
find_python() {
  local c exe
  for c in python3 python py; do
    command -v "$c" >/dev/null 2>&1 || continue
    if [ "$c" = py ]; then exe="$(py -3 -c 'import sys; assert sys.version_info >= (3, 7); print(sys.executable)' 2>/dev/null | nocr)"
    else exe="$("$c" -c 'import sys; assert sys.version_info >= (3, 7); print(sys.executable)' 2>/dev/null | nocr)"; fi
    [ -n "$exe" ] || continue
    is_windows && exe="$(cygpath -u "$exe")"
    printf '%s' "$exe"; return 0
  done
  return 1
}
PY="${PY:-$(find_python || true)}"
