#!/usr/bin/env bash
# Renders feature-graphic.html to the 1024 x 500 PNG Play Console needs.
# usage (from the repo root):  bash release/play-store/render_feature_graphic.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
browser="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
[ -x "$browser" ] || browser="/c/Program Files/Google/Chrome/Application/chrome.exe"
page="file:///$(cygpath -m "$here/feature-graphic.html")"
out="$(cygpath -w "$here/feature-graphic-1024x500.png")"
"$browser" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --force-device-scale-factor=1 --window-size=1024,500 --screenshot="$out" "$page"
echo "wrote $out"
