#!/bin/zsh
set -eu
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build -c release --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
APP="$PWD/dist/KiwiBar.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/KiwiBar "$APP/Contents/MacOS/KiwiBar"
python3 - "$APP" "$PWD/.env" "${1:-}" <<'PY'
import plistlib,sys
from pathlib import Path
plist={'CFBundleExecutable':'KiwiBar','CFBundleIdentifier':'com.norvyn.KiwiBar','CFBundleName':'KiwiBar','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.0','CFBundleVersion':'1','LSMinimumSystemVersion':'14.0','LSUIElement':True,'NSHighResolutionCapable':True}
if sys.argv[3] != '--distribution': plist['BandwagonEnvPath']=sys.argv[2]
with (Path(sys.argv[1])/'Contents/Info.plist').open('wb') as f: plistlib.dump(plist,f)
PY
codesign --force --sign - "$APP"
print "Built $APP"
