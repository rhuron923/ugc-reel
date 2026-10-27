#!/usr/bin/env bash
# enhancor.sh — the one transport ugc-reel uses to talk to Enhancor (Seedance 2.5) and to stage input files.
#
#   enhancor.sh setup-key [--file PATH]   store YOUR Enhancor API key: macOS Keychain (default on a Mac) or a key file readable
#                                         only by you (default on Linux and Windows: ~/.config/ugc-reel/enhancor.key)
#   enhancor.sh where                     print OS, helper path and which key source would be used (no key shown)
#   enhancor.sh check                     find your key, prove it authenticates (free, queues nothing), check staging + CDN
#   enhancor.sh cost <seconds> [720p|480p] [text|video]   quote credits and dollars from the pinned rates (no network)
#   enhancor.sh submit <body.json>        queue ONE generation (spends credits, cannot be cancelled). Prints the JSON response.
#   enhancor.sh status <request_id>       one status poll. Prints the JSON response.
#   enhancor.sh wait <request_id> [max_seconds]   poll every 10 s until COMPLETED/FAILED (default cap 900 s)
#   enhancor.sh upload <file>             stage a local file somewhere Enhancor can fetch it; prints the URL (see config.env)
#
# Each person uses their OWN Enhancor API key. It is read into memory for the length of one call and handed to curl on
# stdin: never on the command line, never written to a file by this script (except by setup-key --file, at mode 0600),
# never printed. Key sources, in order: $ENHANCOR_API_KEY · $ENHANCOR_KEY_FILE · the macOS Keychain (service
# "ugc-reel-enhancor") · ./.enhancor_key · ~/.config/ugc-reel/enhancor.key

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/_platform.sh"
USER_CONFIG="$HOME/.config/ugc-reel/config.env"
# shellcheck disable=SC1090,SC1091
{ set -a; [ -f "$HERE/config.env" ] && . "$HERE/config.env"; [ -f "$USER_CONFIG" ] && . "$USER_CONFIG"; set +a; }

KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-ugc-reel-enhancor}"
DEFAULT_KEY_FILE="$HOME/.config/ugc-reel/enhancor.key"
API="https://apireq.enhancor.ai/api/seedance2.5/v1"
RESULT_CDN="https://d2i9jqncnkplwq.cloudfront.net/"
# Enhancor requires a webhook_url on every video job. We poll /status instead, so this is a sink nobody reads.
WEBHOOK_SINK="${ENHANCOR_WEBHOOK_SINK:-https://example.com/ugc-webhook-unused}"
UGC_UPLOAD="${UGC_UPLOAD:-none}"

die() { echo "enhancor.sh: $*" >&2; exit 1; }
need_py() { [ -n "$PY" ] || die "no working Python 3 found; run:  bash \"$HERE/doctor.sh\""; }

find_key_file() {
  local f
  for f in "${ENHANCOR_KEY_FILE:-}" "$PWD/.enhancor_key" "$DEFAULT_KEY_FILE"; do
    [ -n "$f" ] && [ -f "$f" ] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

key_source() {   # prints where the key would come from; never the key
  if [ -n "${ENHANCOR_API_KEY:-}" ]; then echo "env ENHANCOR_API_KEY"; return 0; fi
  if [ -n "${ENHANCOR_KEY_FILE:-}" ] && [ -f "$ENHANCOR_KEY_FILE" ]; then echo "file $ENHANCOR_KEY_FILE"; return 0; fi
  if is_mac && security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$USER" >/dev/null 2>&1; then echo "macOS Keychain"; return 0; fi
  local f; if f="$(find_key_file)"; then echo "file $f"; return 0; fi
  echo "none"; return 1
}

get_key() {
  if [ -n "${ENHANCOR_API_KEY:-}" ]; then printf '%s' "$ENHANCOR_API_KEY"; return 0; fi
  local k f
  if [ -n "${ENHANCOR_KEY_FILE:-}" ] && [ -f "$ENHANCOR_KEY_FILE" ]; then tr -d '[:space:]' < "$ENHANCOR_KEY_FILE"; return 0; fi
  if is_mac && k="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$USER" -w 2>/dev/null)" && [ -n "$k" ]; then
    printf '%s' "$k"; return 0
  fi
  if f="$(find_key_file)"; then tr -d '[:space:]' < "$f"; return 0; fi
  echo "NO_KEY: no Enhancor API key found. In a real terminal run:  bash \"$HERE/enhancor.sh\" setup-key   (your own key from https://app.enhancor.ai/api-dashboard)" >&2
  return 3
}

# api_post PATH BODYFILE — key goes to curl via a stdin config, so it never appears in argv.
api_post() {
  local path="$1" bodyfile="$2"
  local key; key="$(get_key)" || exit 3; [ -n "$key" ] || die "empty API key"
  printf 'header = "x-api-key: %s"\nheader = "Content-Type: application/json"\n' "$key" \
    | curl -sS -K - -X POST "$API$path" --data-binary "@$bodyfile" -w '\n__HTTP__%{http_code}' | nocr
}

cmd_where() {
  echo "os=$(uname) helper=$HERE/enhancor.sh key_source=$(key_source || true) upload=$UGC_UPLOAD library=${UGC_LIBRARY:-unset}"
}

probe_key_with() {  # $1 = key; prints HTTP code of an empty-body queue call (400 = key accepted, nothing queued)
  local tmp out; tmp="$(mktemp)"; echo '{}' > "$tmp"
  out="$(printf 'header = "x-api-key: %s"\nheader = "Content-Type: application/json"\n' "$1" \
        | curl -sS -K - -X POST "$API/queue" --data-binary "@$tmp" -w '\n__HTTP__%{http_code}' | nocr)"; rm -f "$tmp"
  printf '%s' "$out"
}

cmd_check() {
  echo "0/4 environment: $(uname), key source: $(key_source || true)"
  echo "1/4 looking for your Enhancor API key ..."
  local key; key="$(get_key)" || exit 3; [ -n "$key" ] || die "empty key"
  echo "    found (length ${#key}, not shown)"
  echo "2/4 auth probe (empty body, cannot queue a job) ..."
  local out code body
  out="$(probe_key_with "$key")"; code="${out##*__HTTP__}"; body="${out%$'\n'__HTTP__*}"
  case "$code" in
    400) echo "    ok, key accepted (HTTP 400 validation error is the expected answer: $body)";;
    401|403) die "Enhancor rejected your key (HTTP $code): $body. Re-run:  bash \"$HERE/enhancor.sh\" setup-key   with a fresh key from https://app.enhancor.ai/api-dashboard";;
    *) die "unexpected HTTP $code: $body";;
  esac
  echo "3/4 file staging for Enhancor (UGC_UPLOAD=$UGC_UPLOAD) ..."
  case "$UGC_UPLOAD" in
    s3)
      if [ -n "${UGC_S3_BUCKET:-}" ] && command -v aws >/dev/null 2>&1; then
        aws s3api list-objects-v2 --bucket "$UGC_S3_BUCKET" --prefix "${UGC_S3_PREFIX:-ugc-inputs}/" --max-items 1 >/dev/null 2>&1 \
          && echo "    ok (s3://$UGC_S3_BUCKET/${UGC_S3_PREFIX:-ugc-inputs}/)" \
          || echo "    not available (no AWS login or no access to the bucket). Normal runs are unaffected; only local packshots and beat repairs that need an uploaded still are."
      else echo "    not configured (UGC_UPLOAD=s3 needs UGC_S3_BUCKET and the aws CLI). See README.md."; fi;;
    cmd)
      if [ -n "${UGC_UPLOAD_CMD:-}" ]; then echo "    custom command configured: $UGC_UPLOAD_CMD (not tested here)"
      else echo "    not configured (UGC_UPLOAD=cmd needs UGC_UPLOAD_CMD). See README.md."; fi;;
    *) echo "    none. Packshots must have public URLs; beat repairs that need an uploaded still are off. See README.md to enable.";;
  esac
  echo "4/4 result downloads (Enhancor CDN) ..."
  if curl -sS -o /dev/null -m 10 -I "$RESULT_CDN" 2>/dev/null; then echo "    reachable"
  else echo "    WARNING: cannot reach $RESULT_CDN from this shell. Finished videos could not be downloaded. Check your network or proxy."; fi
  echo "READY."
}

cmd_setup_key() {
  local FILE_OUT=""
  if [ "${1:-}" = "--file" ]; then FILE_OUT="${2:-}"; [ -n "$FILE_OUT" ] || die "usage: setup-key --file <path>"; fi
  if ! is_mac && [ -z "$FILE_OUT" ]; then FILE_OUT="$DEFAULT_KEY_FILE"; fi
  [ -t 0 ] || die "run this in a real terminal window (it asks for your key with hidden input)"
  echo "Get your key at https://app.enhancor.ai/api-dashboard (your own account; jobs bill to its credits)."
  local KEY; read -r -s -p "Paste your Enhancor API key (hidden): " KEY; echo
  KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"; [ -n "$KEY" ] || die "empty key"
  echo "Testing it with Enhancor (free, queues nothing) ..."
  local out code; out="$(probe_key_with "$KEY")"; code="${out##*__HTTP__}"
  case "$code" in
    400) echo "    accepted.";;
    401|403) die "Enhancor rejected that key (HTTP $code). Nothing was saved. Check you copied the whole key.";;
    *) die "unexpected HTTP $code from Enhancor. Nothing was saved.";;
  esac
  if [ -n "$FILE_OUT" ]; then
    mkdir -p "$(dirname "$FILE_OUT")"; ( umask 077; printf '%s\n' "$KEY" > "$FILE_OUT" ); chmod 600 "$FILE_OUT"
    unset KEY
    if is_windows; then
      # chmod does not restrict access on NTFS: drop inherited permissions and grant only the current user.
      MSYS_NO_PATHCONV=1 icacls "$(cygpath -w "$FILE_OUT")" /inheritance:r /grant:r "${USERNAME}:F" >/dev/null \
        || die "saved $FILE_OUT but could not restrict its permissions with icacls"
      echo "Saved to $FILE_OUT (readable only by ${USERNAME}). Keep it out of OneDrive or other synced folders and never zip it. Verifying ..."
    else
      echo "Saved to $FILE_OUT (permissions 600). Keep it out of shared or synced folders and never zip it. Verifying ..."
    fi
    ENHANCOR_KEY_FILE="$FILE_OUT" cmd_check
  else
    # security -i reads the command from stdin, so the key never appears in a process listing.
    printf 'add-generic-password -U -s "%s" -a "%s" -w "%s"\n' "$KEYCHAIN_SERVICE" "$USER" "$KEY" | security -i >/dev/null \
      || die "could not write to the Keychain"
    unset KEY
    echo "Saved to your macOS Keychain (item: $KEYCHAIN_SERVICE). Verifying ..."
    cmd_check
  fi
}

cmd_cost() {
  # Pinned rates, verified against the live API 2026-09-25. 1 credit ≈ $0.001. See references/enhancor-api.md.
  local secs="${1:-}" res="${2:-720p}" kind="${3:-text}"; [ -n "$secs" ] || die "usage: cost <seconds> [720p|480p] [text|video]"
  need_py
  "$PY" - "$secs" "$res" "$kind" <<'PY'
import sys
secs, res, kind = float(sys.argv[1]), sys.argv[2], sys.argv[3]
rates = {("720p","text"): 269.3, ("480p","text"): 122.2, ("720p","video"): 165.5, ("480p","video"): 75.1}
r = rates.get((res, kind))
if r is None: sys.exit("cost: unknown combination %s %s" % (res, kind))
cr = secs * r
print("%g s at %s (%s-driven): %.0f credits ≈ $%.2f (rate %.1f credits/s, pinned 2026-09-25; the cost field on the finished job is the record)" % (secs, res, kind, cr, cr/1000, r))
PY
}

cmd_submit() {
  local f="${1:-}"; [ -f "$f" ] || die "usage: enhancor.sh submit <body.json>"
  # Guard rails: this call spends credits and cannot be cancelled.
  need_py
  "$PY" - "$f" <<'PY' || exit 1
import json, sys
b = json.load(open(sys.argv[1], encoding="utf-8"))
missing = [k for k in ("mode", "duration", "resolution") if k not in b]
if missing:
    sys.exit("enhancor.sh: refusing to submit: body is missing " + ", ".join(missing) +
             ". (Duration defaults to 10 s and any valid body is charged immediately.)")
if b["mode"] not in ("text_to_video","first_n_last_frames","multi_reference","edit","extend","multi_frame","lipsyncing","voice_clone","ugc"):
    sys.exit("enhancor.sh: unknown mode " + str(b["mode"]))
if b["mode"] == "multi_reference" and not (b.get("images") or b.get("videos")):
    sys.exit("enhancor.sh: multi_reference needs at least one image or video URL")
PY
  local tmp; tmp="$(mktemp)"
  "$PY" - "$f" "$tmp" "$WEBHOOK_SINK" <<'PY'
import json, sys
b = json.load(open(sys.argv[1], encoding="utf-8"))
b.setdefault("webhook_url", sys.argv[3]); b.setdefault("webhookUrl", sys.argv[3])
b.setdefault("aspect_ratio", "9:16"); b.setdefault("output_format", "mp4")
b.setdefault("pass_faces", True); b.setdefault("full_access", True)
json.dump(b, open(sys.argv[2], "w", encoding="utf-8"))
PY
  local out; out="$(api_post /queue "$tmp")"; rm -f "$tmp"
  local code="${out##*__HTTP__}" body="${out%$'\n'__HTTP__*}"
  echo "$body"
  [ "$code" = "200" ] || { echo "enhancor.sh: HTTP $code" >&2; exit 1; }
}

cmd_status() {
  local id="${1:-}"; [ -n "$id" ] || die "usage: enhancor.sh status <request_id>"
  local tmp; tmp="$(mktemp)"; printf '{"request_id":"%s"}' "$id" > "$tmp"
  local out; out="$(api_post /status "$tmp")"; rm -f "$tmp"
  printf '%s' "${out%$'\n'__HTTP__*}"; echo
}

cmd_wait() {
  local id="${1:-}" max="${2:-900}" waited=0
  [ -n "$id" ] || die "usage: enhancor.sh wait <request_id> [max_seconds]"; need_py
  while [ "$waited" -lt "$max" ]; do
    local s st
    s="$(cmd_status "$id")"
    st="$(printf '%s' "$s" | "$PY" -c 'import sys,json
try: print(json.load(sys.stdin).get("status",""))
except Exception: print("")' | nocr)"
    case "$st" in COMPLETED|FAILED) echo "$s"; return 0;; esac
    sleep 10; waited=$((waited+10))
  done
  echo "enhancor.sh: still running after ${max}s. The job is NOT lost. Poll again: enhancor.sh wait $id" >&2
  exit 2
}

cmd_upload() {
  local f="${1:-}"; [ -f "$f" ] || die "usage: enhancor.sh upload <file>"
  case "$UGC_UPLOAD" in
    s3)
      [ -n "${UGC_S3_BUCKET:-}" ] || die "UGC_UPLOAD=s3 but UGC_S3_BUCKET is not set (see README.md)"
      command -v aws >/dev/null 2>&1 || die "the aws CLI is not installed (brew install awscli)"
      local name key; name="$(basename "$f" | tr ' ' '_')"
      key="${UGC_S3_PREFIX:-ugc-inputs}/$(date +%Y%m%d)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')-$name"
      aws s3 cp "$f" "s3://$UGC_S3_BUCKET/$key" --only-show-errors >&2 || die "upload failed (check your AWS login and bucket access)"
      aws s3 presign "s3://$UGC_S3_BUCKET/$key" --expires-in 86400 | nocr;;
    cmd)
      [ -n "${UGC_UPLOAD_CMD:-}" ] || die "UGC_UPLOAD=cmd but UGC_UPLOAD_CMD is not set (see README.md)"
      local url; url="$(eval "$UGC_UPLOAD_CMD" '"$f"' | nocr | tail -1)"
      case "$url" in http://*|https://*) echo "$url";; *) die "UGC_UPLOAD_CMD did not print a URL (got: $url)";; esac;;
    *) die "file staging is not configured (UGC_UPLOAD=none). Set UGC_UPLOAD=s3 or cmd in ~/.config/ugc-reel/config.env; see README.md.";;
  esac
}

case "${1:-}" in
  setup-key) shift; cmd_setup_key "$@";;
  where)  shift; cmd_where "$@";;
  check)  shift; cmd_check "$@";;
  cost)   shift; cmd_cost "$@";;
  submit) shift; cmd_submit "$@";;
  status) shift; cmd_status "$@";;
  wait)   shift; cmd_wait "$@";;
  upload) shift; cmd_upload "$@";;
  *) sed -n '2,19p' "${BASH_SOURCE[0]}"; exit 1;;
esac
