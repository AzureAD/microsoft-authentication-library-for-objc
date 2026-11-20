#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/AuthPlatform/iOS/Resources/ApplePasswordManager"
BASE="https://raw.githubusercontent.com/apple/password-manager-resources/main"

mkdir -p "$DEST"
while IFS=' ' read -r upstream_path local_name; do
  [[ -z "$upstream_path" ]] && continue
  tmp="$(mktemp)"
  curl --fail --silent --show-error --location "$BASE/$upstream_path" -o "$tmp"
  jq empty "$tmp"
  mv "$tmp" "$DEST/$local_name"
done <<'FILES'
quirks/password-rules.json password-rules.json
quirks/shared-credentials.json shared-credentials.json
quirks/shared-credentials-historical.json shared-credentials-historical.json
quirks/change-password-URLs.json change-password-URLs.json
quirks/websites-that-append-2fa-to-password.json websites-that-append-2fa-to-password.json
quirks/apple-appIDs-to-domains-shared-credentials.json apple-appIDs-to-domains-shared-credentials.json
quirks/websites-that-ask-for-credentials-for-other-services-when-embedded-as-third-party.json websites-that-ask-for-credentials-for-other-services-when-embedded-as-third-party.json
FILES

WEB_DEST="$ROOT/AuthPlatform/Web/public/password-manager-resources"
mkdir -p "$WEB_DEST"
cp "$DEST"/*.json "$WEB_DEST/"
cp "$DEST/LICENSE.md" "$WEB_DEST/LICENSE.md"

echo "Updated Apple password-manager resource snapshots for iOS and web. Review the diff and commit intentionally."
