# Release notes

## 1.2.0

- Install KiwiBar as a prebuilt universal Homebrew Cask. No Xcode is required; the app lives in a real `/Applications/KiwiBar.app` directory.
- Developer ID signing, Apple notarization and a stapled ticket for release downloads.
- Add an opt-in **Launch at Login** switch in Settings using the macOS login-item service. Default: off.
- Preserve the Bundle ID, existing Keychain credentials, menu bar percentage, resource gauges, history charts and refresh controls.

### Upgrade from the Formula

Install with `brew install --cask n0rvyn/kiwibar/kiwibar` while keeping the old Formula. Quit the old app, open `/Applications/KiwiBar.app`, allow Keychain access if macOS asks, and confirm your host metrics appear. Only then run `brew uninstall --formula kiwibar`. No credential reset is needed.
