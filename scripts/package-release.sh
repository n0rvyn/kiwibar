#!/bin/zsh
# Uses an existing signing identity and notary profile/API key. Never creates credentials.
set -eu
cd "${0:A:h:h}"
: "${SIGNING_IDENTITY:?Set an existing Developer ID Application identity}"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
else
  : "${NOTARY_KEY_PATH:?Set NOTARY_PROFILE or existing NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER}"
  : "${NOTARY_KEY_ID:?Missing NOTARY_KEY_ID}"
  : "${NOTARY_ISSUER:?Missing NOTARY_ISSUER}"
  NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
fi
./scripts/build-app.sh --distribution
APP="$PWD/dist/KiwiBar.app"
codesign -dvv "$APP" 2>&1 | /usr/bin/grep -q 'Authority=Developer ID Application:'
lipo "$APP/Contents/MacOS/KiwiBar" -verify_arch arm64 x86_64
VERSION=$(cat VERSION)
SUBMISSION_DIR=$(mktemp -d "$PWD/dist/notary.XXXXXX")
SUBMISSION="$SUBMISSION_DIR/KiwiBar.zip"
trap 'rm -f "$SUBMISSION"; rmdir "$SUBMISSION_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ditto -c -k --keepParent "$APP" "$SUBMISSION"
xcrun notarytool submit "$SUBMISSION" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ARCHIVE="$PWD/dist/KiwiBar-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ARCHIVE"
SHA256=$(shasum -a 256 "$ARCHIVE" | cut -d ' ' -f 1)
mkdir -p Casks
cat > Casks/kiwibar.rb <<CASK
cask "kiwibar" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/n0rvyn/kiwibar/releases/download/v#{version}/KiwiBar-#{version}.zip?download=1"
  name "KiwiBar"
  desc "Menu bar monitor for Bandwagon Host"
  homepage "https://github.com/n0rvyn/kiwibar"

  depends_on macos: :sonoma

  app "KiwiBar.app"
end
CASK
print "$SHA256  KiwiBar-$VERSION.zip"
