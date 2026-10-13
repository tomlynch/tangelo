#!/usr/bin/env bash
# Builds a signed, notarized Tangelo release ready to upload to GitHub.
#
#   scripts/release.sh v0.1.0-alpha.1
#
# Produces build/release/<tag>/ containing:
#   Tangelo-<tag>.dmg                    signed, notarized and stapled disk image
#   VLCKit-source-<commit>.tar.gz        source of the bundled VLCKit (LGPL-2.1 section 6)
#   vlc-source-<commit>.tar.gz           source of the libVLC inside it
#   SHA256SUMS.txt                       checksums for all of the above
#
# Needs: a "Developer ID Application" certificate in the keychain, and an App Store Connect API key
# described by ~/.appstoreconnect/config.json ({"key_id", "issuer_id", "key_path"}) for notarization.
# Override TEAM_ID or ASC_CONFIG in the environment to use different credentials.
set -euo pipefail

TAG="${1:?usage: scripts/release.sh <tag, e.g. v0.1.0-alpha.1>}"
TEAM_ID="${TEAM_ID:-WSE286KUH5}"
ASC_CONFIG="${ASC_CONFIG:-$HOME/.appstoreconnect/config.json}"
SIGN_IDENTITY="Developer ID Application"

# VLCKit binary package pinned in scripts/fetch-vlckit.sh: VLCKit-3.7.3-<vlckit commit>-<vlc commit>.
VLCKIT_COMMIT="319ed2c0"
VLC_COMMIT="79128878"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/build/release/${TAG}"
WORK="${OUT}/work"
APP_NAME="Tangelo"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

notary_args() {
  python3 -I - "${ASC_CONFIG}" <<'PY'
import json, os, sys
c = json.load(open(sys.argv[1]))
print(os.path.expanduser(c["key_path"]), c["key_id"], c["issuer_id"], sep="\n")
PY
}

notarize() {
  local file="$1"
  local creds key key_id issuer
  creds="$(notary_args)"
  key="$(sed -n 1p <<<"${creds}")"; key_id="$(sed -n 2p <<<"${creds}")"; issuer="$(sed -n 3p <<<"${creds}")"
  local result
  result="$(xcrun notarytool submit "${file}" --key "${key}" --key-id "${key_id}" --issuer "${issuer}" \
              --wait --output-format json)"
  local status id
  status="$(python3 -I -c 'import json,sys; print(json.load(sys.stdin)["status"])' <<<"${result}")"
  id="$(python3 -I -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"${result}")"
  echo "Notarization ${status} (${id})"
  if [[ "${status}" != "Accepted" ]]; then
    xcrun notarytool log "${id}" --key "${key}" --key-id "${key_id}" --issuer "${issuer}" "${WORK}/notary-${id}.json" || true
    echo "error: notarization failed; log saved to ${WORK}/notary-${id}.json" >&2
    exit 1
  fi
}

[[ "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "error: tag should look like v1.2.3 or v1.2.3-alpha.1" >&2; exit 1; }
VERSION="${TAG#v}"
MARKETING_VERSION="${VERSION%%-*}"  # CFBundleShortVersionString must be numeric: 0.1.0-alpha.1 -> 0.1.0
BUILD_NUMBER="$(git -C "${ROOT}" rev-list --count HEAD)"

IDENTITY_HASH="$(security find-identity -v -p codesigning | grep "${SIGN_IDENTITY}: .*(${TEAM_ID})" | head -1 | awk '{print $2}')"
[[ -n "${IDENTITY_HASH}" ]] || { echo "error: no '${SIGN_IDENTITY}' certificate for team ${TEAM_ID} in the keychain" >&2; exit 1; }
[[ -z "$(git -C "${ROOT}" status --porcelain --untracked-files=no)" ]] \
  || echo "warning: working tree has uncommitted changes; the release won't match a commit exactly" >&2

rm -rf "${OUT}"
mkdir -p "${WORK}"

step "Preparing ${TAG} (version ${MARKETING_VERSION}, build ${BUILD_NUMBER})"
"${ROOT}/scripts/fetch-vlckit.sh"
(cd "${ROOT}" && xcodegen generate --quiet)

step "Archiving (universal, hardened runtime, Developer ID)"
xcodebuild -project "${ROOT}/${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release \
  -archivePath "${WORK}/${APP_NAME}.xcarchive" -destination 'generic/platform=macOS' \
  MARKETING_VERSION="${MARKETING_VERSION}" CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
  ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="${TEAM_ID}" \
  CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" OTHER_CODE_SIGN_FLAGS="--timestamp" \
  archive -quiet

cat > "${WORK}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>${SIGN_IDENTITY}</string>
</dict></plist>
EOF

step "Exporting signed app"
xcodebuild -exportArchive -archivePath "${WORK}/${APP_NAME}.xcarchive" \
  -exportOptionsPlist "${WORK}/ExportOptions.plist" -exportPath "${WORK}/export" -quiet
APP="${WORK}/export/${APP_NAME}.app"
codesign --verify --deep --strict --verbose=1 "${APP}"
lipo -archs "${APP}/Contents/MacOS/${APP_NAME}"

step "Notarizing the app"
ditto -c -k --keepParent "${APP}" "${WORK}/${APP_NAME}.zip"
notarize "${WORK}/${APP_NAME}.zip"
xcrun stapler staple "${APP}"

step "Building the disk image"
STAGING="${WORK}/dmg"
mkdir -p "${STAGING}"
ditto "${APP}" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"
DMG="${OUT}/${APP_NAME}-${TAG}.dmg"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING}" -fs HFS+ -format UDZO -ov "${DMG}" -quiet
codesign --sign "${IDENTITY_HASH}" --timestamp "${DMG}"

step "Notarizing the disk image"
notarize "${DMG}"
xcrun stapler staple "${DMG}"

step "Checking Gatekeeper"
spctl --assess --type execute --verbose=2 "${APP}"
spctl --assess --type open --context context:primary-signature --verbose=2 "${DMG}"

step "Fetching engine source for LGPL compliance"
curl -fsSL "https://code.videolan.org/videolan/VLCKit/-/archive/${VLCKIT_COMMIT}/VLCKit-${VLCKIT_COMMIT}.tar.gz" \
  -o "${OUT}/VLCKit-source-${VLCKIT_COMMIT}.tar.gz"
curl -fsSL "https://code.videolan.org/videolan/vlc/-/archive/${VLC_COMMIT}/vlc-${VLC_COMMIT}.tar.gz" \
  -o "${OUT}/vlc-source-${VLC_COMMIT}.tar.gz"

step "Checksums"
(cd "${OUT}" && shasum -a 256 ./*.dmg ./*.tar.gz | sed 's#  \./#  #' > SHA256SUMS.txt && cat SHA256SUMS.txt)

echo
echo "Release ready in ${OUT}"
