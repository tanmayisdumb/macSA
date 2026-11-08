# macSA

**GTA San Andreas, native on Apple Silicon.** A build that renders directly through
**Metal**, runs sharp at native **Retina** and ultrawide resolutions, supports modern game
controllers, and turns on macOS **Game Mode** automatically. One command turns your own copy
of the original game — Steam, retail disc, Wine/CrossOver wrapper, or files from an old PC —
into a ready-to-play `Grand Theft Auto San Andreas.app`. No administrator password, Homebrew,
or Xcode needed.

This repository hosts the **launcher, installer, and build tools only** — there are no proprietary game assets distributed here.

> ⚠️ **This needs the original GTA San Andreas (v1.0 US), not the Definitive Edition.** The
> Definitive Edition is a different, rebuilt Unreal Engine game and will not work.

---

## Quick Install

**You need:** an Apple Silicon Mac (M1, M2, M3, M4 or newer) on macOS 13 (Ventura) or later, and
your own copy of the **original GTA San Andreas** — the classic 2004/2005 PC
release (v1.0 US works out of the box; other versions are automatically patched by the installer).

### 1. Run the one-liner in Terminal

Open **Terminal** (`Cmd+Space`, type `Terminal`, press Enter), paste this line and press Enter:

```sh
curl -fsSL https://raw.githubusercontent.com/tanmayisdumb/macSA/main/quick-install.sh | bash
```

It automatically finds your game files (Steam install, existing app, or any San Andreas folder in `~/Downloads`), applies compatibility patches, configures high-DPI settings, and bakes **Grand Theft Auto San Andreas.app** directly into your Downloads folder in seconds.

### 2. Play

When Finder opens, **drag Grand Theft Auto San Andreas into Applications** — or just double-click it to play right away!

---

## Custom Game Paths & Options

### Using a non-Steam copy or custom folder?
Add the path to your GTA San Andreas folder (the folder containing `gta_sa.exe` and `models/gta3.img`) or any `.app` containing the files (including Cider, Wine, CrossOver, and Wineskin wrappers):

```sh
curl -fsSL https://raw.githubusercontent.com/tanmayisdumb/macSA/main/quick-install.sh | bash -s -- ~/Downloads/"Grand Theft Auto San Andreas"
```

### Prefer a classic disk image?
Add `--dmg` to produce a drag-to-Applications `Grand Theft Auto San Andreas.dmg`:

```sh
curl -fsSL https://raw.githubusercontent.com/tanmayisdumb/macSA/main/quick-install.sh | bash -s -- --dmg
```

### Upgrading?
Run the same one-liner again at any time — it automatically reuses the game files already baked into your installed app without re-downloading or re-extracting assets.

---

## Direct Downloads

| File | Description |
|---|---|
| [`macSA-macos-arm64.tar.gz`](https://raw.githubusercontent.com/tanmayisdumb/macSA/main/macSA-macos-arm64.tar.gz) | Standalone app bundle without game assets, for manual packaging |
| [`macSA-macos-arm64.zip`](https://raw.githubusercontent.com/tanmayisdumb/macSA/main/macSA-macos-arm64.zip) | Same standalone app bundle in `.zip` format |
| [`quick-install.sh`](https://raw.githubusercontent.com/tanmayisdumb/macSA/main/quick-install.sh) | The interactive installer script run by the one-liner |
| [`signtool-arm64.tar.gz`](https://raw.githubusercontent.com/tanmayisdumb/macSA/main/signtool-arm64.tar.gz) | Bundled ad-hoc code signer (`ldid`), ensuring zero Xcode dependency |
| [`version.sha`](https://raw.githubusercontent.com/tanmayisdumb/macSA/main/version.sha) | SHA256 checksum of the native runtime binary |

---

## Legal

`macSA` requires the files from your own legally purchased copy of the original Grand Theft Auto: San Andreas. No game assets, textures, or audio files are distributed here.

`macSA` is an independent open-source project and is not affiliated with, sponsored by, or endorsed by Rockstar Games or Take-Two Interactive. Grand Theft Auto and San Andreas are trademarks of Take-Two Interactive Software, Inc.

---

## What's Changed in this Port

The goal of `macSA` is a faithful, flawless native Mac experience: authentic gameplay, look, and audio, powered by modern Apple Silicon hardware underneath.

### 🌴 Authentic Name and Retina Icon
- **Installed as `Grand Theft Auto San Andreas.app` with an authentic 1024x1024 Retina icon** — created directly from high-resolution vector artwork. The app name on disk, in the menu bar, in Activity Monitor, and in the macOS Dock all match the original title.

### ⚡ Rendering: Direct3D 9 → Apple Metal
- Runs natively on Apple Silicon (`arm64`) through a specialized translation engine that maps DirectX 9 draw calls directly to **Apple Metal**.
- Zero Rosetta 2 translation overhead, zero legacy OpenGL deprecation warnings.
- Flawlessly renders weather effects, heat haze, smog, vehicle specular reflections, and ambient shadows.

### 🖥️ Native 2560x1600 Resolution by Default
- **Defaults to 2560 x 1600 x 32**: Both the internal engine mode lookup table and user configuration (`gta_sa.set`) are hard-patched to initialize at **2560 x 1600 x 32** rather than 800x600.
- **Introsort mode index alignment**: The launcher sets `m_nPrefsVideoMode` and `m_nDisplayVideoMode` directly to the primary 2560x1600 Metal backbuffer mode, ensuring the in-game display options menu reflects the native panel resolution immediately upon launch.
- **Widescreen On by default**: `m_bWidescreenOn` starts enabled, preventing 4:3 stretched aspect ratios on modern displays.

### 🏎️ Smooth Frame Pacing & 60+ FPS Engine
- **Frame Limiter Off by default**: The legacy 30 FPS cap is disabled by default (`m_bPrefsFrameLimiter = 0`), allowing San Andreas to run fluidly on high-refresh-rate Mac displays.
- **Uncapped Engine (`GTA_UNCAP=1`)**: Eliminates artificial internal tick clamps.
- **VSync Synchronization (`GTA_VSYNC=1`)**: Locks frame presentation to your Mac's display refresh rate (including 120Hz ProMotion on MacBook Pro), eliminating screen tearing and physics jitter.

### 🎮 Modern Input & Camera Controls
- **Inverted Mouse Look by default**: `bInvertMouseY = 1` starts enabled out of the box, matching modern third-person camera conventions.
- **Native Game Controllers**: Built-in support for PlayStation DualSense / DualShock 4, Xbox Wireless, Nintendo Switch Pro Controller, and MFi gamepads via Apple's native `GameController.framework`.
- **Mouse Capture**: In fullscreen, the mouse cursor remains captured inside the window, preventing accidental clicks outside the game or triggering the macOS Dock.

### 🛠️ Automatic Executable Compatibility Patching
- **Auto-detection of clean v1.0 US binary**: Saif requires the clean 14.3 MB (14,383,616 bytes) v1.0 US executable. Many European, retail, and digital releases come with 15.8 MB SecuROM-encrypted executables that crash on startup.
- `macSA` bundles the clean v1.0 US compatibility binary in `Contents/Resources` and automatically backs up and upgrades incompatible executables during install and launch.
- Automatically patches the hardcoded resolution search routine at `0x746362` inside `gta_sa.exe` so the binary natively targets 2560x1600.

### 🍎 macOS Integration
- **Game Mode Automatic Activation**: Tagged with official game metadata (`LSApplicationCategoryType: public.app-category.games`). macOS automatically enables **Game Mode** in fullscreen, prioritizing CPU and GPU cores and doubling Bluetooth sampling rates for wireless controllers.
- **Self-contained bundle**: All game files are baked into `Contents/Resources/GameData/`. Moving the `.app` moves the entire game without leaving scattered dependencies.
- **Spaces & Mission Control Friendly**: Transitions smoothly into native macOS fullscreen spaces with seamless `Cmd+Tab` app switching.

---

## Building from Source

To build `macSA.app` from scratch on macOS:

```sh
# Clone this repository
git clone https://github.com/tanmayisdumb/macSA.git
cd macSA

# Build launcher, download runtime, and package archives
./src/build.sh
```

The build script compiles the native C launcher (`src/macSA.c`), sets up the bundle skeleton, embeds the icon and compatibility binaries, cleans AppleDouble metadata, ad-hoc codesigns the bundle, and outputs `macSA-macos-arm64.tar.gz` and `macSA-macos-arm64.zip`.

---

## Credits

- **[macVC](https://github.com/gtamac/macVC)** by [gtamac](https://github.com/gtamac) — Project inspiration & architecture
- **[saif-runtime](https://github.com/saif-runtime/saif-runtime)** — Apple Silicon Metal runtime & DirectX translation
- **[GTA-reversed](https://github.com/gta-reversed/gta-reversed)** — GTA San Andreas reverse-engineering research
- **[plugin-sdk](https://github.com/DK22Pac/plugin-sdk)** by DK22Pac — C++ structures & engine offsets
- **[re3 / reVC](https://github.com/halfc/re3)** — Foundational 3D-era GTA reverse-engineering
- **[Procursus (ldid)](https://github.com/ProcursusTeam/ldid)** — Ad-hoc bundle codesigning
- **[Rockstar Games](https://www.rockstargames.com/)** — Original creators of Grand Theft Auto: San Andreas
