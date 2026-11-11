# KiwiBar

A small native macOS menu bar monitor for Bandwagon Host / KiwiVM.

A server icon and monthly transfer percentage stay in your menu bar. Click for RAM, swap and mapped disk gauges, load average, and CPU, network and disk history charts. Refreshes every five minutes, with manual refresh.

## Run locally

Requires macOS 14+ and Xcode 26+ (Swift 6.2).

```sh
./scripts/build-app.sh
open dist/KiwiBar.app
```

Settings opens on first launch. Enter your **VEID** and **API key**, then click **Save & Connect**. Use the gear button in the metrics panel to edit them later. The API key stays masked, and both values are stored in macOS Keychain.

## Homebrew

The source formula builds for your Mac and requires Xcode 26+:

```sh
brew tap n0rvyn/kiwibar https://github.com/n0rvyn/kiwibar
brew install n0rvyn/kiwibar/kiwibar
open "$(brew --prefix kiwibar)/KiwiBar.app"
```

Enter your credentials in the app. No configuration file is needed or installed.

## Metric details

- Transfer usage and allowance apply the provider's `monthly_data_multiplier`.
- RAM usage is plan RAM minus available memory. Mapped disk is allocated image space, not guest filesystem usage.
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
