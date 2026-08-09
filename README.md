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

`LSUIElement` is set so the app stays in the menu bar (no Dock icon).

## Usage

1. Click the Eithernet icon in the menu bar.
2. Under **Wired**, toggle any Ethernet / LAN adapters.
3. Under **Wireless**, toggle Wi‑Fi interfaces.
4. Use **Refresh** if interfaces change (cable plugged/unplugged).

## Notes

- Uses `/usr/sbin/networksetup` under the hood.
- List items are network interfaces/services (not Wi‑Fi SSIDs).
- Wired detection looks for hardware ports named like Ethernet / LAN.
- Disabling a service may require elevated privileges depending on your Mac’s configuration.
