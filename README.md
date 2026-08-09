# Eithernet

macOS menu bar app to toggle **Ethernet / Wi‑Fi**, join networks, and see your current SSID + IP — from the tray.

## Requirements

- macOS 14+
- Xcode / Swift 6 toolchain
- Permission to change network settings (macOS may prompt; some actions need admin)
- **Location** permission to list nearby Wi‑Fi networks

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
VERSION=1.0.0 ./scripts/package-dmg.sh
open dist/Eithernet-1.0.0.dmg
```

Optional overrides:

```bash
VERSION=1.0.0 BUILD=12 ./scripts/package-dmg.sh
```

`LSUIElement` is set so the app stays in the menu bar (no Dock icon).

## Release (GitHub Actions)

Push a version tag to build a DMG on `macos-15` and attach it to a GitHub Release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow lives at `.github/workflows/release.yml`. Builds are currently unsigned (Gatekeeper may warn until you add Apple signing + notarization).

## Usage

1. Click the Eithernet icon in the menu bar (state changes with wired / wireless / both / off).
2. Under **Wired**, toggle any Ethernet / LAN adapters.
3. Under **Wireless**, toggle Wi‑Fi power and tap a network name to join it.
4. Check the header for connected SSID and IPv4.
5. Use **Wi‑Fi Settings…** or **Eithernet Settings…** for system Wi‑Fi prefs and app options (including Launch at Login).
6. Use **Refresh** to rescan interfaces and nearby SSIDs.

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
