#!/usr/bin/env bash
# Renders design/icon/Tangelo.svg into every size the asset catalog needs.
# Needs Google Chrome (for faithful SVG filter rendering) and ImageMagick (`brew install imagemagick`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="${ROOT}/design/icon/Tangelo.svg"
ICONSET="${ROOT}/Tangelo/Resources/Assets.xcassets/AppIcon.appiconset"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

python3 -I "${ROOT}/design/icon/generate.py" "${SVG}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
"${CHROME}" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
  --window-size=1024,1024 --screenshot="${WORK}/icon-1024.png" "file://${SVG}" >/dev/null 2>&1
cp "${WORK}/icon-1024.png" "${ROOT}/design/icon/Tangelo-1024.png"

mkdir -p "${ICONSET}"
for points in 16 32 128 256 512; do
  for scale in 1 2; do
    suffix=""; [[ ${scale} == 2 ]] && suffix="@2x"
    magick "${WORK}/icon-1024.png" -filter Lanczos -resize "$((points * scale))x$((points * scale))" \
      "${ICONSET}/icon_${points}x${points}${suffix}.png"
  done
done

python3 -I - "${ICONSET}/Contents.json" <<'PY'
import json, sys
images = [{"idiom": "mac", "size": f"{p}x{p}", "scale": f"{s}x",
           "filename": f"icon_{p}x{p}{'@2x' if s == 2 else ''}.png"}
          for p in (16, 32, 128, 256, 512) for s in (1, 2)]
with open(sys.argv[1], "w") as fh:
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, fh, indent=2)
PY
echo "Icon written to ${ICONSET}"
