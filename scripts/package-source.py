#!/usr/bin/env python3
"""Build a reproducible source archive from an explicit public-file allowlist."""
from pathlib import Path
import gzip
import hashlib
import io
import tarfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / 'VERSION').read_text().strip()
PATHS = ['Package.swift', 'Sources', 'Tests', 'scripts', 'VERSION', '.gitignore', 'README.md']
files = []
for item in PATHS:
    path = ROOT / item
    files.extend(sorted(p for p in path.rglob('*') if p.is_file()) if path.is_dir() else [path])
secrets = []
local_env = ROOT / '.env'
if local_env.exists():
    for line in local_env.read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            value = line.split('=', 1)[1].strip().strip('\"\'')
            if value:
                secrets.append(value.encode())
for path in files:
    relative = path.relative_to(ROOT)
    if path.is_symlink() or any(part in {'.git', '.build', '__pycache__', 'dist'} for part in relative.parts):
        raise SystemExit(f'Unexpected public source path: {relative}')
    data = path.read_bytes()
    if any(secret in data for secret in secrets):
        raise SystemExit(f'Private credential found in public source: {relative}')

out = ROOT / 'dist' / f'KiwiBar-{VERSION}-source.tar.gz'
out.parent.mkdir(exist_ok=True)
with out.open('wb') as output, gzip.GzipFile(filename='', mode='wb', fileobj=output, mtime=0) as compressed:
    with tarfile.open(fileobj=compressed, mode='w') as archive:
        for path in files:
            data = path.read_bytes()
            info = tarfile.TarInfo(f'KiwiBar-{VERSION}/{path.relative_to(ROOT)}')
            info.size = len(data)
            info.mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
            archive.addfile(info, io.BytesIO(data))
checksum = hashlib.sha256(out.read_bytes()).hexdigest()
print(f'{checksum}  {out.name}')
formula = f'''class Kiwibar < Formula
  desc "Native macOS menu bar monitor for Bandwagon Host"
  homepage "https://github.com/n0rvyn/kiwibar"
  url "https://github.com/n0rvyn/kiwibar/releases/download/v{VERSION}/KiwiBar-{VERSION}-source.tar.gz"
  sha256 "{checksum}"
  version "{VERSION}"

  depends_on xcode: ["26.0", :build]
  depends_on macos: :sonoma

  def install
    system "./scripts/build-app.sh", "--distribution"
    prefix.install "dist/KiwiBar.app"
    bin.install_symlink prefix/"KiwiBar.app/Contents/MacOS/KiwiBar" => "kiwibar"
  end

  def caveats
    <<~EOS
      Launch KiwiBar and enter your VEID and API key in Settings:
        open "#{{opt_prefix}}/KiwiBar.app"
      Credentials are saved in macOS Keychain.
    EOS
  end

  test do
    assert_match "KiwiBar", shell_output("#{{bin}}/kiwibar --help")
    assert_equal "{VERSION}", shell_output("#{{bin}}/kiwibar --version").strip
  end
end
'''
(ROOT / 'Formula').mkdir(exist_ok=True)
(ROOT / 'Formula' / 'kiwibar.rb').write_text(formula)
print(f'Packaged {len(files)} public source files; private .env and local notes excluded.')
