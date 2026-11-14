# KiwiBar

A small native macOS menu bar monitor for Bandwagon Host / KiwiVM.

A server icon and monthly transfer percentage stay in your menu bar. Click for RAM, swap and mapped disk gauges, load average, and CPU, network and disk history charts. Refreshes every five minutes, with manual refresh.

## Install with Homebrew

Requires macOS 14 (Sonoma) or later. The Cask downloads a prebuilt universal app for Intel and Apple silicon. Xcode is not required.

```sh
brew tap n0rvyn/kiwibar https://github.com/n0rvyn/kiwibar
brew install --cask n0rvyn/kiwibar/kiwibar
open /Applications/KiwiBar.app
```

Homebrew installs a real `/Applications/KiwiBar.app` directory. Release apps use Developer ID signing, Apple notarization and a stapled ticket.

Settings opens on first launch. Enter your **VEID** and **API key**, then click **Save & Connect**. Use the gear button in the metrics panel to edit them later. Both values stay in macOS Keychain; the API key remains masked.

Enable **Launch at Login** in Settings to start KiwiBar when you sign in. It is off by default and uses the macOS login-item service. If macOS requires approval, use **Open Login Items Settings**. Turn the switch off to remove the login item.

### Migrating from the source Formula

Keep the old Formula until the Cask app has launched and read your existing credentials:

```sh
brew install --cask n0rvyn/kiwibar/kiwibar
```

Quit the old KiwiBar using its Quit button, then open `/Applications/KiwiBar.app`. The Bundle ID and Keychain entry remain the same. macOS can request Keychain access because the old Formula app was ad-hoc signed; allow the new signed KiwiBar to read the existing entry. Do not delete or re-enter your credentials to migrate.

After the new app displays your host metrics, remove only the old Formula:

```sh
brew uninstall --formula kiwibar
```

No configuration file is installed. Uninstalling the Cask does not delete Keychain credentials.

## Run from source

Development requires Xcode 26+ (Swift 6.2):

```sh
./scripts/build-app.sh
open dist/KiwiBar.app
```

## Metric details

- Transfer usage and allowance apply the provider's `monthly_data_multiplier`.
- RAM usage is plan RAM minus available memory. Mapped disk is allocated image space, not guest filesystem usage.
- CPU, network and disk history charts show only the last seven days.
- CPU history uses the provider's reported `cpu_usage` values; it does not claim CPU percentage. Network and disk history show byte quantities for each provider sample, not inferred transfer rates. Sample intervals vary across the provider's historical retention tiers.
- Missing metrics display `—` or an unavailable indicator. Hover over throttle icons for their state.
- On a connection error, the last successful values remain visible and are marked stale.

## Privacy and read-only access

The client permits only `getLiveServiceInfo`, `getRawUsageStats` and `getRateLimitStatus` on `https://api.64clouds.com/v1/`. Credentials go in a form-encoded HTTPS POST body; redirects are refused. There are no server mutation controls. Provider API keys can carry broader permissions; the app's endpoint whitelist restricts its own calls.

Metrics stay in memory. Credentials are stored only in macOS Keychain; the app does not read or write plaintext credential files. Local development secrets and API notes remain excluded from Git.

## Development

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
swift test --disable-sandbox --cache-path .build/cache \
  --config-path .build/config --security-path .build/security
```

`--disable-sandbox` disables SwiftPM's nested manifest sandbox for constrained build hosts; it does not change the app's network or operating-system permissions.

Diagnostic mode makes the same read-only requests and prints connection status without credentials:

```sh
.build/debug/KiwiBar --probe
```

Sample-only chart rendering (no server request):

```sh
.build/debug/KiwiBar --render /tmp/kiwibar.png --sample --dark
```

This renders the chart content. AppKit-backed native controls require the running app for visual verification.

## Release builds

On the release Mac, set `SIGNING_IDENTITY` to an existing Developer ID Application identity and `NOTARY_PROFILE` to an existing notarytool Keychain profile, then run:

```sh
./scripts/package-release.sh
```

Alternatively supply existing `NOTARY_KEY_PATH`, `NOTARY_KEY_ID` and `NOTARY_ISSUER`. The script builds both architectures, signs with hardened runtime, submits to Apple, staples and validates the ticket, assesses Gatekeeper, and generates the final ZIP and Cask SHA256. It never creates signing or API credentials. Publish that exact ZIP under the matching source tag; do not rebuild the archive after computing its checksum.
