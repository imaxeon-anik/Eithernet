# Eithernet

Menu bar app for macOS that lets you enable or disable **wired** and **wireless** network interfaces from the tray.

## Requirements

- macOS 14+
- Xcode / Swift 6 toolchain
- Permission to change network settings (macOS may prompt; some actions need admin)

## Build & run

```bash
cd ~/Documents/GitHub/Eithernet
swift build
swift run
```

## Package as a menu-bar `.app`

```bash
./scripts/package-app.sh
open dist/Eithernet.app
```

Icons are generated (SF Symbols–like menu-bar templates + app icon):

```bash
./scripts/generate-icons.swift
```

Outputs: `Sources/Eithernet/Resources/menubar-*.png` and `Resources/AppIcon.icns`.

## Package a `.dmg`

```bash
./scripts/package-dmg.sh
open dist/Eithernet-0.1.0.dmg
```

Optional version overrides:

```bash
VERSION=0.2.0 BUILD=12 ./scripts/package-dmg.sh
```

`LSUIElement` is set so the app stays in the menu bar (no Dock icon).

## Release (GitHub Actions)

Push a version tag to build a DMG on `macos-15` and attach it to a GitHub Release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow lives at `.github/workflows/release.yml`. Builds are currently unsigned (Gatekeeper may warn until you add Apple signing + notarization).

## Usage

1. Click the Eithernet icon in the menu bar (custom plug/Wi‑Fi glyph; state changes with what’s enabled).
2. Under **Wired**, toggle any Ethernet / LAN adapters.
3. Under **Wireless**, toggle Wi‑Fi power and tap a network name to join it.
4. Use **Refresh** to rescan interfaces and nearby SSIDs.

## Launch at Login

From the menu bar panel: **Eithernet Settings…** → enable **Launch at Login**.

Or manually: System Settings → General → Login Items → add `Eithernet.app`.

macOS may ask you to approve the item under Login Items the first time.

## Notes

- Interface power uses `/usr/sbin/networksetup`; Wi‑Fi join uses CoreWLAN.
- Listing nearby networks requires **Location** permission (macOS privacy rule for Wi‑Fi scans).
- Wired detection looks for hardware ports named like Ethernet / LAN.
- Disabling a service may require elevated privileges depending on your Mac’s configuration.
- Launch at Login uses `SMAppService` and works from the packaged `.app` (not `swift run` debug builds).
