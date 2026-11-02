#!/usr/bin/env bash
# Renders the six framed Play Store phone screenshots (1080 x 1920 PNG).
# usage (from the repo root):  bash release/play-store/screenshots/render_screenshots.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
browser="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
[ -x "$browser" ] || browser="/c/Program Files/Google/Chrome/Application/chrome.exe"
page="file:///$(cygpath -m "$here/frame.html")"
for n in 1 2 3 4 5 6; do
  out="$(cygpath -w "$here/phone-$n.png")"
  "$browser" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=1 --window-size=1080,1920 --screenshot="$out" "$page#$n" >/dev/null 2>&1
  echo "wrote $out"
done
