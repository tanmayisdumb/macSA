#!/bin/bash
# macSA quick builder for macOS (Apple Silicon).
#
# Transforms your existing copy of Grand Theft Auto: San Andreas (Steam, retail,
# or PC files) into a native Apple Silicon macOS app ("Grand Theft Auto San Andreas.app").
# Renders natively through Metal, supports Retina resolutions, full gamepads,
# and activates macOS Game Mode automatically.
#
# Nothing here requires administrator privileges, Homebrew, or Xcode.
#
# Usage: quick-install.sh [--dmg] [game_files_dir]
#   --dmg            also wrap the app in a drag-to-Applications
#                    "Grand Theft Auto San Andreas.dmg"
#   game_files_dir   optional folder that contains the game files (gta_sa.exe or
#                    models/gta3.img) — e.g. from a Windows PC — or a .app that
#                    contains them (Steam, Wineskin, Wine, CrossOver wrapper).
#                    If omitted, the script auto-detects Steam, existing installs,
#                    or copies in ~/Downloads.
set -euo pipefail

RELEASE_URL="https://raw.githubusercontent.com/gtamac/macSA/main/macSA-macos-arm64.tar.gz"
SIGNTOOL_URL="https://raw.githubusercontent.com/gtamac/macSA/main/signtool-arm64.tar.gz"
DL="$HOME/Downloads"
APP_NAME="Grand Theft Auto San Andreas"
VOLNAME="$APP_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

STEAM_SRCS=(
	"$HOME/Library/Application Support/Steam/steamapps/common/Grand Theft Auto San Andreas/Grand Theft Auto - San Andreas.app/Contents/Resources/transgaming/c_drive/Program Files/Rockstar Games/Grand Theft Auto San Andreas"
	"$HOME/Library/Application Support/Steam/steamapps/common/grand theft auto san andreas/Grand Theft Auto - San Andreas.app/Contents/Resources/transgaming/c_drive/Program Files/Rockstar Games/Grand Theft Auto San Andreas"
	"$HOME/Library/Application Support/Steam/steamapps/common/Grand Theft Auto San Andreas"
	"$HOME/Library/Application Support/Steam/steamapps/common/grand theft auto san andreas"
)

# ---------------------------------------------------------------------------
# Presentation & Styling
# ---------------------------------------------------------------------------
FANCY=no
[ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && FANCY=yes || true

if [ "$FANCY" = yes ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]; then
	# San Andreas Grove Street Green & California Gold gradient
	G1=$'\033[38;5;46m'   G2=$'\033[38;5;47m'   G3=$'\033[38;5;48m'
	G4=$'\033[38;5;178m'  G5=$'\033[38;5;214m'  G6=$'\033[38;5;208m'
	G7=$'\033[38;5;202m'
	ACCENT=$'\033[38;5;48m' GOLD=$'\033[38;5;220m'
	GREEN=$'\033[38;5;84m'  RED=$'\033[38;5;203m'
	CYAN=$'\033[38;5;51m'
	BOLD=$'\033[1m' DIM=$'\033[2m' RESET=$'\033[0m'
elif [ "$FANCY" = yes ]; then
	G1=$'\033[92m' G2=$'\033[92m' G3=$'\033[32m'
	G4=$'\033[33m' G5=$'\033[93m' G6=$'\033[93m' G7=$'\033[91m'
	ACCENT=$'\033[92m' GOLD=$'\033[93m'
	GREEN=$'\033[92m'  RED=$'\033[91m'
	CYAN=$'\033[96m'
	BOLD=$'\033[1m' DIM=$'\033[2m' RESET=$'\033[0m'
else
	G1= G2= G3= G4= G5= G6= G7= ACCENT= GOLD= GREEN= RED= CYAN= BOLD= DIM= RESET=
fi

SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
BAR_WIDTH=24

banner() {
	printf '\n'
	printf '  %s                               ███████╗ █████╗ %s\n' "$G1" "$RESET"
	printf '  %s███╗   ███╗  █████╗   ██████╗  ██╔════╝██╔══██╗%s\n' "$G2" "$RESET"
	printf '  %s████╗ ████║ ██╔══██╗ ██╔════╝  ███████╗███████║%s\n' "$G3" "$RESET"
	printf '  %s██╔████╔██║ ███████║ ██║       ╚════██║██╔══██║%s\n' "$G4" "$RESET"
	printf '  %s██║╚██╔╝██║ ██╔══██║ ██║       ███████║██║  ██║%s\n' "$G5" "$RESET"
	printf '  %s██║ ╚═╝ ██║ ██║  ██║ ╚██████╗  ╚══════╝╚═╝  ╚═╝%s\n' "$G6" "$RESET"
	printf '  %s╚═╝     ╚═╝ ╚═╝  ╚═╝  ╚═════╝                  %s\n' "$G7" "$RESET"
	printf '\n'
	printf '  %sGrand Theft Auto: San Andreas · Metal · Apple Silicon%s\n' "$DIM" "$RESET"
	printf '\n'
}

STEPS_TOTAL=5
STEP=0
step() {
	STEP=$((STEP + 1))
	printf '\n%s◆%s %s[%d/%d]%s %s\n' "$GOLD" "$RESET" "$BOLD" "$STEP" "$STEPS_TOTAL" "$RESET" "$1"
}
ok()   { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$1"; }
die() {
	printf '  %s✘ error:%s %s\n' "$RED" "$RESET" "$1" >&2
	shift
	local line
	for line in "$@"; do printf '    %s\n' "$line" >&2; done
	exit 1
}

hsize() {
	awk -v b="${1:-0}" 'BEGIN {
		u[1]="B"; u[2]="KB"; u[3]="MB"; u[4]="GB"; i=1
		while (b >= 1024 && i < 4) { b /= 1024; i++ }
		if (i == 1) printf "%d %s", b, u[i]; else printf "%.1f %s", b, u[i]
	}'
}

file_bytes() { stat -f%z "$1" 2>/dev/null || echo 0; }
du_bytes() {
	local kb
	kb=$(du -sk "$1" 2>/dev/null | awk 'NR==1 {print $1}')
	echo $(( ${kb:-0} * 1024 ))
}

draw_bar() {
	local glyph=$1 label=$2 cur=$3 total=$4
	local pct=0 filled=0 bar='' j=0 tdisp='?'
	if [ "$total" -gt 0 ]; then
		pct=$((cur * 100 / total))
		[ "$pct" -gt 100 ] && pct=100
		tdisp=$(hsize "$total")
	fi
	filled=$((pct * BAR_WIDTH / 100))
	while [ "$j" -lt "$BAR_WIDTH" ]; do
		if [ "$j" -lt "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
		j=$((j + 1))
	done
	printf '\r  %s %s %s%s%s %3d%%  %s%s / %s%s\033[K' \
		"$glyph" "$label" "$GOLD" "$bar" "$RESET" "$pct" \
		"$DIM" "$(hsize "$cur")" "$tdisp" "$RESET"
}

watch_bytes() {
	local pid=$1 label=$2 total=$3
	shift 3
	local i=0 rc=0 cur=0
	printf '\033[?25l'
	while kill -0 "$pid" 2>/dev/null; do
		cur=$("$@" 2>/dev/null || echo 0)
		draw_bar "${CYAN}${SPIN[$((i % 10))]}${RESET}" "$label" "$cur" "$total"
		i=$((i + 1))
		sleep 0.2
	done
	wait "$pid" || rc=$?
	printf '\033[?25h'
	if [ "$rc" -eq 0 ]; then
		if [ "$total" -le 0 ]; then
			total=$("$@" 2>/dev/null || echo 0)
		fi
		draw_bar "${GREEN}✔${RESET}" "$label" "$total" "$total"
		printf '\n'
	else
		printf '\r  %s✘%s %s failed\033[K\n' "$RED" "$RESET" "$label"
	fi
	return "$rc"
}

run_task() {
	local label=$1
	shift
	if [ "$FANCY" = no ]; then
		echo "==> $label"
		"$@"
		return
	fi
	local i=0 rc=0 pid
	"$@" &
	pid=$!
	printf '\033[?25l'
	while kill -0 "$pid" 2>/dev/null; do
		printf '\r  %s%s%s %s\033[K' "$CYAN" "${SPIN[$((i % 10))]}" "$RESET" "$label"
		i=$((i + 1))
		sleep 0.1
	done
	wait "$pid" || rc=$?
	printf '\033[?25h'
	if [ "$rc" -eq 0 ]; then
		printf '\r  %s✔%s %s\033[K\n' "$GREEN" "$RESET" "$label"
	else
		printf '\r  %s✘%s %s failed\033[K\n' "$RED" "$RESET" "$label"
	fi
	return "$rc"
}

# ---------------------------------------------------------------------------
# Options & Compatibility
# ---------------------------------------------------------------------------
WANT_DMG=no
GAME_ARG=""
for arg in "$@"; do
	case "$arg" in
		--dmg) WANT_DMG=yes ;;
		*) GAME_ARG="$arg" ;;
	esac
done

banner

if [ "$(uname -sm)" != "Darwin arm64" ]; then
	die "this installer is for Apple Silicon Macs (arm64) only"
fi

OS_VER="$(sw_vers -productVersion)"
OS_MAJOR="$(echo "$OS_VER" | cut -d. -f1)"
if [ "$OS_MAJOR" -lt 13 ]; then
	die "macSA requires macOS 13 (Ventura) or newer (you have $OS_VER)"
fi

TMP=""
DEV=""
cleanup() {
	kill $(jobs -p) 2>/dev/null || true
	[ -n "$DEV" ] && hdiutil detach "$DEV" >/dev/null 2>&1 || true
	[ -n "$TMP" ] && rm -rf "$TMP"
	[ "$FANCY" = yes ] && printf '\033[?25h' || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Step 1: Locating game files
# ---------------------------------------------------------------------------
step "Locating original GTA: San Andreas game files"

resolve_game_dir() {
	local base="${1%/}" root dir
	local wine_sa="drive_c/Program Files (x86)/Rockstar Games/Grand Theft Auto San Andreas"
	local wine_sa_64="drive_c/Program Files/Rockstar Games/Grand Theft Auto San Andreas"
	for root in "$base" "$base.app"; do
		for dir in \
			"$root" \
			"$root/Contents/Resources/GameData" \
			"$root/Contents/Resources/transgaming/c_drive/Program Files/Rockstar Games/Grand Theft Auto San Andreas" \
			"$root/Contents/SharedSupport/prefix/$wine_sa" \
			"$root/Contents/SharedSupport/prefix/$wine_sa_64" \
			"$root/$wine_sa" \
			"$root/$wine_sa_64"
		do
			if [ -f "$dir/models/gta3.img" ] || [ -f "$dir/gta_sa.exe" ] || [ -f "$dir/gta-sa.exe" ] || [ -f "$dir/GTA_SA.EXE" ]; then
				echo "$dir"
				return 0
			fi
		done
	done
	return 1
}

# Check existing installs for upgrades
EXISTING_SRC=""
EXISTING_APP=""
for app in "/Applications/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app" "$DL/$APP_NAME.app" \
           "/Applications/macSA.app"     "$HOME/Applications/macSA.app"     "$DL/macSA.app" \
           "/Applications/Saif.app"      "$HOME/Applications/Saif.app"      "$DL/Saif.app"; do
	if [ -d "$app/Contents/Resources/GameData" ] && ( [ -f "$app/Contents/Resources/GameData/models/gta3.img" ] || [ -f "$app/Contents/Resources/GameData/gta_sa.exe" ] ); then
		EXISTING_SRC="$app/Contents/Resources/GameData"
		EXISTING_APP="$app"
		break
	fi
done

if [ -n "$GAME_ARG" ]; then
	if ! ASSET_SRC="$(resolve_game_dir "$GAME_ARG")"; then
		die "no game files (gta_sa.exe or models/gta3.img) found in $GAME_ARG" \
			"Pass the folder that contains your game files, or a San Andreas .app that holds them."
	fi
	ok "Using game files from $ASSET_SRC"
elif [ -n "$EXISTING_SRC" ]; then
	ASSET_SRC="$EXISTING_SRC"
	ok "Using game files from existing install: $EXISTING_APP"
else
	# Search Steam
	ASSET_SRC=""
	for steam_cand in "${STEAM_SRCS[@]}"; do
		if [ -f "$steam_cand/models/gta3.img" ] || [ -f "$steam_cand/gta_sa.exe" ]; then
			ASSET_SRC="$steam_cand"
			ok "Using game files from Steam ($steam_cand)"
			break
		fi
	done

	# Fallback: scan ~/Downloads for folders or .apps containing San Andreas files
	if [ -z "$ASSET_SRC" ]; then
		for cand in "$DL"/*; do
			[ -e "$cand" ] || continue
			c_lower="$(basename "$cand" | tr '[:upper:]' '[:lower:]')"
			case "$c_lower" in
				*san*andreas*|*gtasa*|*gta*sa*)
					if ASSET_SRC="$(resolve_game_dir "$cand")"; then
						ok "Using game files found in $ASSET_SRC"
						break
					fi
					;;
			esac
		done
	fi

	if [ -z "$ASSET_SRC" ]; then
		die "GTA: San Andreas game files not found" \
			"macSA requires your original GTA: San Andreas PC game files (v1.0 US)." \
			"You can point the installer directly to your game folder or wrapper:" \
			"  $0 /path/to/SanAndreas" \
			"or drop a copy into ~/Downloads with \"San Andreas\" in its name."
	fi
fi

TMP="$(mktemp -d)"
APP="$TMP/$APP_NAME.app"
GDATA="$APP/Contents/Resources/GameData"

# ---------------------------------------------------------------------------
# Step 2: Unpacking / Downloading macSA
# ---------------------------------------------------------------------------
step "Preparing macSA bundle"

LOCAL_TAR="$SCRIPT_DIR/macSA-macos-arm64.tar.gz"
if [ -f "$LOCAL_TAR" ]; then
	ok "Using local macSA package"
	cp "$LOCAL_TAR" "$TMP/macSA.tar.gz"
else
	if [ "$FANCY" = yes ]; then
		DL_TOTAL="$(curl -sIL "$RELEASE_URL" 2>/dev/null \
			| awk 'tolower($1)=="content-length:" {cl=$2} END {printf "%d", cl}' || echo 0)"
		case "$DL_TOTAL" in ''|*[!0-9]*) DL_TOTAL=0 ;; esac
		curl -fsSL -o "$TMP/macSA.tar.gz" "$RELEASE_URL" &
		watch_bytes $! "macSA-macos-arm64.tar.gz" "$DL_TOTAL" file_bytes "$TMP/macSA.tar.gz" \
			|| die "download failed — check your connection"
	else
		echo "==> Downloading macSA..."
		curl -fL --progress-bar -o "$TMP/macSA.tar.gz" "$RELEASE_URL"
	fi
fi

run_task "Unpacking app bundle" tar -xzf "$TMP/macSA.tar.gz" -C "$TMP"
mv "$TMP/macSA.app" "$APP"

/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" \
	-c "Set :CFBundleDisplayName $APP_NAME" "$APP/Contents/Info.plist" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 3: Baking game files into the app
# ---------------------------------------------------------------------------
step "Baking game files into the app bundle"

mkdir -p "$GDATA"
bake_files() {
	cp -R "$ASSET_SRC/." "$GDATA/"
}

if [ "$FANCY" = yes ]; then
	BAKE_TOTAL=$(du_bytes "$ASSET_SRC")
	bake_files &
	watch_bytes $! "Copying game assets" "$BAKE_TOTAL" du_bytes "$GDATA" \
		|| die "copying the game files failed"
else
	echo "==> Baking game files into the app..."
	bake_files
fi

# Ensure executable permissions inside GameData if needed
[ -f "$GDATA/gta_sa.exe" ] && chmod +x "$GDATA/gta_sa.exe" || true

# ---------------------------------------------------------------------------
# Step 4: Signing the app
# ---------------------------------------------------------------------------
step "Ad-hoc signing the app bundle"

sign_bundle() {
	xattr -cr "$APP" 2>/dev/null || true

	# Check if native codesign works
	if codesign --force --sign - "$APP/Contents/MacOS/SaifRuntime" 2>/dev/null && \
	   codesign --force --sign - "$APP/Contents/MacOS/macSA" 2>/dev/null && \
	   codesign --force --deep --sign - "$APP" 2>/dev/null; then
		return 0
	fi

	# Fallback to bundled signtool (ldid)
	local SIGNTOOL_TAR="$SCRIPT_DIR/signtool-arm64.tar.gz"
	if [ ! -f "$SIGNTOOL_TAR" ]; then
		curl -fsSL -o "$TMP/signtool.tar.gz" "$SIGNTOOL_URL" || return 1
		SIGNTOOL_TAR="$TMP/signtool.tar.gz"
	fi
	tar -xzf "$SIGNTOOL_TAR" -C "$TMP" || return 1
	local LDID="$TMP/signtool/ldid"
	export DYLD_LIBRARY_PATH="$TMP/signtool:${DYLD_LIBRARY_PATH:-}"
	chmod +x "$LDID"

	local BUNDLE_ID
	BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
		"$APP/Contents/Info.plist" 2>/dev/null || echo "com.github.gtamac.macSA")"

	for lib in "$APP"/Contents/Frameworks/*.dylib "$APP"/Contents/Frameworks/*.framework/*; do
		[ -f "$lib" ] || continue
		"$LDID" -Cadhoc -S "$lib" 2>/dev/null || true
	done

	"$LDID" -Cadhoc -S "$APP/Contents/MacOS/SaifRuntime" || return 1
	"$LDID" -Cadhoc -I"$BUNDLE_ID" -S "$APP/Contents/MacOS/macSA" || return 1
}

run_task "Ad-hoc signing app bundle" sign_bundle || die "code signing failed"

# ---------------------------------------------------------------------------
# Step 5: Finalizing & Installing
# ---------------------------------------------------------------------------
step "Finishing installation"

outro() {
	printf '\n'
	printf '%s✔ Done!%s %s\n' "$GREEN$BOLD" "$RESET" "$1"
	printf '  %s\n' "$2"
	printf '  macOS enables %sGame Mode%s automatically.\n' "$BOLD" "$RESET"
	printf '\n'
	printf '       %s🌴  Welcome to San Andreas  🌴%s\n' "$GOLD" "$RESET"
	printf '       %sfinished in %dm %02ds%s\n' "$DIM" $((SECONDS / 60)) $((SECONDS % 60)) "$RESET"
	printf '\n'
}

mkdir -p "$DL"

if [ "$WANT_DMG" = no ]; then
	rm -rf "$DL/$APP_NAME.app"
	mv "$APP" "$DL/$APP_NAME.app"
	ok "Placed $APP_NAME.app in $DL"
	outro "$DL/$APP_NAME.app is ready." \
		"Drag it into Applications (or double-click it) to play."
	open -R "$DL/$APP_NAME.app"
	exit 0
fi

# Build DMG
STAGE="$TMP/stage"
mkdir -p "$STAGE"
mv "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
TMPDMG="$TMP/rw.dmg"

dmg_create() { hdiutil create -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW "$TMPDMG" >/dev/null; }
run_task "Creating disk image" dmg_create || die "disk image creation failed"

DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$TMPDMG" | grep -E '^/dev/' | awk 'NR==1{print $1}')

osascript >/dev/null 2>&1 <<APPLESCRIPT || true
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 900, 430}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set position of item "$APP_NAME.app" of container window to {130, 165}
    set position of item "Applications" of container window to {370, 165}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEV" >/dev/null 2>&1; DEV=""
rm -f "$DL/$APP_NAME.dmg"
dmg_convert() { hdiutil convert "$TMPDMG" -format UDZO -imagekey zlib-level=9 -o "$DL/$APP_NAME.dmg" >/dev/null; }
run_task "Compressing disk image" dmg_convert || die "compressing disk image failed"

ok "Created $DL/$APP_NAME.dmg"
outro "$DL/$APP_NAME.dmg is ready." \
	"Opening it now — drag Grand Theft Auto San Andreas into Applications."
open "$DL/$APP_NAME.dmg"
