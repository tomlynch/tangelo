#!/usr/bin/env bash
# Downloads the pinned VLCKit binary package from VideoLAN and unpacks it into Vendor/.
# VLCKit is LGPL-2.1-or-later; it is fetched rather than committed so the repo only holds our own code.
set -euo pipefail

VERSION="3.7.3"
PACKAGE="VLCKit-3.7.3-319ed2c0-79128878.tar.xz"
SHA256="019afdae4e2e2d0f3ac325fac8f7ba0af25dca70b9d157df7d60db88e0be8e5d"
URL="https://download.videolan.org/pub/cocoapods/prod/${PACKAGE}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${ROOT}/Vendor"
STAMP="${VENDOR}/.vlckit-version"

if [[ -f "${STAMP}" && "$(cat "${STAMP}")" == "${PACKAGE}" && -d "${VENDOR}/VLCKit.xcframework" ]]; then
  echo "VLCKit ${VERSION} already present."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo "Downloading ${PACKAGE}..."
curl -fsSL "${URL}" -o "${WORK}/${PACKAGE}"

echo "${SHA256}  ${WORK}/${PACKAGE}" | shasum -a 256 -c -

tar -xf "${WORK}/${PACKAGE}" -C "${WORK}"
SRC="${WORK}/VLCKit - binary package"

rm -rf "${VENDOR}/VLCKit.xcframework"
mkdir -p "${VENDOR}"
cp -R "${SRC}/VLCKit.xcframework" "${VENDOR}/"
cp "${SRC}/COPYING.txt" "${VENDOR}/VLCKit-COPYING.txt"
echo "${PACKAGE}" > "${STAMP}"

echo "VLCKit ${VERSION} installed to Vendor/."
