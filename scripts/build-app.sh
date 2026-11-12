#!/bin/zsh
set -eu
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
BUILD_ARGS=()
if [[ "${1:-}" == --distribution ]]; then
  : "${SIGNING_IDENTITY:?Set an existing Developer ID Application identity}"
  BUILD_ARGS=(--arch arm64 --arch x86_64)
fi
swift build -c release "${BUILD_ARGS[@]}" --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
BIN_DIR=$(swift build -c release "${BUILD_ARGS[@]}" --show-bin-path --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security)
APP="$PWD/dist/KiwiBar.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/KiwiBar" "$APP/Contents/MacOS/KiwiBar"
python3 - "$APP" "$(cat VERSION)" <<'PY'
import plistlib,re,sys
from pathlib import Path
version = sys.argv[2]
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('Invalid VERSION')
plist={'CFBundleExecutable':'KiwiBar','CFBundleIdentifier':'com.norvyn.KiwiBar','CFBundleName':'KiwiBar','CFBundlePackageType':'APPL','CFBundleShortVersionString':version,'CFBundleVersion':version,'LSMinimumSystemVersion':'14.0','LSUIElement':True,'NSHighResolutionCapable':True}
with (Path(sys.argv[1])/'Contents/Info.plist').open('wb') as f: plistlib.dump(plist,f)
PY
if [[ "${1:-}" == --distribution ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
print "Built $APP"
