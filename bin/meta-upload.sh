#!/usr/bin/env bash
# meta-upload.sh — builds a Meta bulk-import sheet from a campaign's "Approved for testing" folder.
# Usage: bash bin/meta-upload.sh "<campaign folder>" --pattern "<one-ad export.xlsx>" [--skip "<text>"] [--since YYYY-MM-DD]
# Read-only on Meta. Needs Node 22.15+ and ~/.config/ugc-reel/meta.env (README → Meta bulk upload).
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --use-system-ca lets Node trust networks or antivirus that inspect HTTPS.
exec node --use-system-ca "$here/meta-upload.mjs" "$@"
