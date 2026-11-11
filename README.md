# KiwiBar

A small native macOS menu bar monitor for Bandwagon Host / KiwiVM.

A server icon and monthly transfer percentage stay in your menu bar. Click for RAM, swap and mapped disk gauges, load average, and CPU, network and disk history charts. Refreshes every five minutes, with manual refresh.

## Run locally

Requires macOS 14+ and Xcode 26+ (Swift 6.2).

Put your KiwiVM credentials in `.env` at the project root:

```dotenv
VEID=your_vps_id
API_KEY=your_api_key
```

```sh
./scripts/build-app.sh
open dist/KiwiBar.app
```

The local build points to your existing `.env`; credentials are never copied into the app.

## Homebrew

The source formula builds for your Mac and requires Xcode 26+:

```sh
brew tap n0rvyn/kiwibar https://github.com/n0rvyn/kiwibar
brew install n0rvyn/kiwibar/kiwibar
mkdir -p ~/.config/kiwibar
cp "$(brew --prefix kiwibar)/share/kiwibar/.env.example" ~/.config/kiwibar/.env
chmod 600 ~/.config/kiwibar/.env
```

Fill in `VEID` and `API_KEY` in that file, then launch:

```sh
open "$(brew --prefix kiwibar)/KiwiBar.app"
```

## Metric details

- Transfer usage and allowance apply the provider's `monthly_data_multiplier`.
- RAM usage is plan RAM minus available memory. Mapped disk is allocated image space, not guest filesystem usage.
- CPU history uses the provider's reported `cpu_usage` values; it does not claim CPU percentage. Network and disk history show byte quantities for each provider sample, not inferred transfer rates. Sample intervals vary across the provider's historical retention tiers.
- Missing metrics display `—` or an unavailable indicator. Hover over throttle icons for their state.
- On a connection error, the last successful values remain visible and are marked stale.

## Privacy and read-only access

The client permits only `getLiveServiceInfo`, `getRawUsageStats` and `getRateLimitStatus` on `https://api.64clouds.com/v1/`. Credentials go in a form-encoded HTTPS POST body; redirects are refused. There are no server mutation controls. Provider API keys can carry broader permissions; the app's endpoint whitelist restricts its own calls.

Responses stay in memory. The app does not save metrics, console images, IP addresses or credentials. `.env` files and local API notes are excluded from Git.

## Development

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
swift test --disable-sandbox --cache-path .build/cache \
  --config-path .build/config --security-path .build/security
```

`--disable-sandbox` disables SwiftPM's nested manifest sandbox for constrained build hosts; it does not change the app's network or operating-system permissions.

Diagnostic mode makes the same read-only requests and prints status and response field names without credentials:

```sh
.build/debug/KiwiBar --probe --env "$PWD/.env"
```

Sample-only chart rendering (no server request):

```sh
.build/debug/KiwiBar --render /tmp/kiwibar.png --sample --dark
```

This renders the chart content. AppKit-backed native controls require the running app for visual verification.
