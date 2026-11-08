# macSA

**GTA San Andreas, native on Apple Silicon.** A high-performance build that renders directly through
**Metal**, runs sharp at full **Retina** and ultrawide resolutions, supports modern game controllers natively,
and turns on macOS **Game Mode** automatically. One command turns your own copy of the original game —
Steam, retail disc, Wine/CrossOver wrapper, or files from an old PC — into a ready-to-play, self-contained
`Grand Theft Auto San Andreas.app`. No administrator password, Homebrew, or Xcode required.

> ⚠️ **This needs the original GTA San Andreas (v1.0 US), not the Definitive Edition.**
> The Definitive Edition is a different, rebuilt game engine and is not supported.

---

## Quick Install

**You need:** an Apple Silicon Mac (M1, M2, M3, M4 or newer) on macOS 13 (Ventura) or later, and
your own copy of the **original GTA San Andreas** — the classic 2004/2005 PC
release (v1.0 US).

### 1. Run the one-liner in Terminal
Open **Terminal** (`Cmd+Space`, type `Terminal`, press Enter), paste this line and press Enter:

```sh
curl -fsSL https://raw.githubusercontent.com/gtamac/macSA/main/quick-install.sh | bash
```

*(Or if you cloned/downloaded this repository locally, just run: `./quick-install.sh`)*

It automatically detects your game files (Steam install, existing app, or any San Andreas folder in `~/Downloads`)
and places a finished **Grand Theft Auto San Andreas.app** in your Downloads folder in seconds.

### 2. Play
When Finder opens, drag **Grand Theft Auto San Andreas** into your **Applications** folder — or just double-click it to play right away!

---

## Custom Game Paths & Options

### Using a non-Steam copy or custom folder?
Pass the path to your GTA San Andreas folder (the one containing `gta_sa.exe` and `models/gta3.img`) or any `.app` containing the files (including Cider, Wine, CrossOver, and Wineskin wrappers):

```sh
./quick-install.sh /path/to/"Grand Theft Auto San Andreas"
```

### Want a drag-to-Applications `.dmg` disk image?
Add `--dmg` to create a distributable drag-and-drop disk image:

```sh
./quick-install.sh --dmg
```

### Upgrading?
Run the installer again at any time. It automatically reuses the baked game files from your existing `Grand Theft Auto San Andreas.app` or `macSA.app` without requiring the original installer or Steam.

---

## Direct Downloads

| File | Description |
|---|---|
| [`macSA-macos-arm64.tar.gz`](macSA-macos-arm64.tar.gz) | The prebuilt macOS app template (no game assets included) |
| [`macSA-macos-arm64.zip`](macSA-macos-arm64.zip) | The same prebuilt app bundle in `.zip` format |
| [`quick-install.sh`](quick-install.sh) | The interactive installer script |
| [`signtool-arm64.tar.gz`](signtool-arm64.tar.gz) | Bundled ad-hoc code signer (`ldid`), ensuring zero Xcode CLT dependency |
| [`version.sha`](version.sha) | SHA256 checksum of the native runtime binary |

---

## Features & Highlights

### ⚡ Apple Silicon & Metal Architecture
- **Pure arm64 execution**: Runs natively on Apple Silicon without emulation overhead or Rosetta 2 bottlenecks.
- **Metal Graphics Backend**: Direct translation of DirectX 9 graphics pipelines directly to Apple Metal shaders and commands. No legacy OpenGL deprecation warnings.
- **macOS Game Mode**: Bundled with official macOS game metadata (`LSApplicationCategoryType: public.app-category.games`). macOS automatically enables **Game Mode** in fullscreen, prioritizing CPU/GPU threads and doubling Bluetooth polling rates for wireless controllers.

### 🎮 Modern Display & Controller Support
- **Full Retina & Ultrawide Resolution**: Crisply scales to your display's native panel resolution (including 4K, 5K, and Pro Display XDR).
- **Native Game Controllers**: Built-in support for PlayStation DualSense / DualShock 4, Xbox Wireless, Nintendo Switch Pro Controller, and MFi gamepads via Apple's native `GameController.framework`.
- **Spaces & Mission Control Friendly**: Starts seamlessly and transitions into native macOS fullscreen spaces with smooth `Cmd+Tab` switching.

### 📦 Clean Self-Contained Bundle
- **Self-contained**: All your game data (`models`, `audio`, `data`, `anim`) is baked directly inside `Grand Theft Auto San Andreas.app/Contents/Resources/GameData/`.
- **Zero system pollution**: The app does not install kernel extensions, daemons, or background services.
- **Built-in Launcher**: Features a fast C launcher binary that instantly boots the game directly into San Andreas while retaining interactive fallback if game data is missing.

---

## Troubleshooting & Requirements

- **Supported Game Version:** GTA San Andreas v1.0 US PC release (`gta_sa.exe` compact or standard HOODLUM 14.3 MB / 13.7 MB builds). If your copy is v2.0 or modern Steam, use a standard 1-click v1.0 US downgrader first.
- **Save Games:** Game saves and user files are safely stored in `~/Library/Application Support/saif/` and `~/Documents/GTA San Andreas User Files/`.
- **macOS Requirements:** macOS 13 (Ventura), macOS 14 (Sonoma), macOS 15 (Sequoia), macOS 26 (Tahoe) or newer on Apple Silicon (M1/M2/M3/M4/M5).

---

## Legal

`macSA` is an independent project and is not affiliated with, sponsored by, or endorsed by Rockstar Games or Take-Two Interactive. Grand Theft Auto and San Andreas are trademarks of Take-Two Interactive Software, Inc.

This repository **does not distribute any copyrighted game assets, audio files, or game textures**. You must provide your own legally purchased copy of the original Grand Theft Auto: San Andreas.
