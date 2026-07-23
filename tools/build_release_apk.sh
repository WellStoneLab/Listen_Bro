#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUBSPEC_VERSION="$(awk '/^version: / {print $2}' pubspec.yaml)"
if [[ -z "${PUBSPEC_VERSION}" ]]; then
  echo "Error: version not found in pubspec.yaml" >&2
  exit 1
fi

if [[ "${PUBSPEC_VERSION}" == *"+"* ]]; then
  BUILD_NAME="${PUBSPEC_VERSION%%+*}"
  BUILD_NUMBER="${PUBSPEC_VERSION#*+}"
else
  BUILD_NAME="${PUBSPEC_VERSION}"
  BUILD_NUMBER="0"
fi

if ! [[ "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "Error: invalid build number in pubspec.yaml: ${BUILD_NUMBER}" >&2
  exit 1
fi

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${BUILD_NAME}+${NEW_BUILD_NUMBER}"

if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
else
  sed -i "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
fi

SAFE_VERSION="${NEW_VERSION//+/_}"
APK_NAME="Listen_Bro_${SAFE_VERSION}.apk"
OUT_DIR="build/app/outputs/flutter-apk"

echo "Version: ${PUBSPEC_VERSION} -> ${NEW_VERSION}"
echo "Building version: ${BUILD_NAME} (${NEW_BUILD_NUMBER})"

flutter build apk --release \
  --build-name="${BUILD_NAME}" \
  --build-number="${NEW_BUILD_NUMBER}"

cp "${OUT_DIR}/app-release.apk" "${OUT_DIR}/${APK_NAME}"

echo ""
echo "Built: ${OUT_DIR}/${APK_NAME}"
ls -lh "${OUT_DIR}/${APK_NAME}"
echo "pubspec.yaml version: ${NEW_VERSION}"

PUBLISH="${PUBLISH_RELEASE:-0}"
if [[ "${1:-}" == "--release" || "${1:-}" == "-r" ]]; then
  PUBLISH=1
fi

if [[ "${PUBLISH}" == "1" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh (GitHub CLI) が見つかりません。" >&2
    exit 1
  fi

  REPO="${GH_REPO:-WellStoneLab/Listen_Bro}"
  TAG="v${NEW_VERSION}"
  echo ""
  echo "Publishing to GitHub Releases: ${REPO} (${TAG})"

  gh release create "${TAG}" \
    "${OUT_DIR}/${APK_NAME}" \
    --repo "${REPO}" \
    --target Listen_Bro \
    --title "v${BUILD_NAME} (build ${NEW_BUILD_NUMBER})" \
    --notes "Listen_Bro（聞いてよ！マスター）Android APK (build ${NEW_BUILD_NUMBER})"

  echo "Released: ${TAG}"
fi
