#!/usr/bin/env bash
# The Gang Survival: one-step setup for Prism Launcher on macOS/Linux.
# Installs Prism (if missing), creates or refreshes the "The Gang Survival" instance (Minecraft 1.20.1, Fabric 0.20.1),
# wires up the automatic mod sync, and adds the server to the server list. You still sign in with Microsoft inside Prism.
# Safe to re-run. Read it first if you like; it only touches Prism's own folders (and reads ~/Downloads for hand-downloaded files).
set -euo pipefail
INSTANCE="The Gang Survival"
PACK_URL="https://raw.githubusercontent.com/loswastaken/the-gang-survival-pack/main/pack.toml"
BOOT_URL="https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar"
BOOT_SHA="a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c"
SERVERS_B64="CgAACQAHc2VydmVycwoAAAACCAACaXAAG2Rvcmt1bmlmeS5kdWNrZG5zLm9yZzoyNTU2NwgABG5hbWUAEVRoZSBHYW5nIFN1cnZpdmFsAAgAAmlwABExMC4yNC40LjE0MzoyNTU2NwgABG5hbWUAHFRoZSBHYW5nIFN1cnZpdmFsIChob21lL1ZQTikAAA=="
MC_PACK='{"components":[{"cachedName":"Minecraft","cachedVersion":"1.20.1","important":true,"uid":"net.minecraft","version":"1.20.1"},{"cachedName":"Intermediary Mappings","cachedVersion":"1.20.1","dependencyOnly":true,"uid":"net.fabricmc.intermediary","version":"1.20.1"},{"cachedName":"Fabric Loader","cachedVersion":"0.20.1","uid":"net.fabricmc.fabric-loader","version":"0.20.1"}],"formatVersion":1}'

say() { printf '\n==> %s\n' "$*"; }
sha1() { if command -v sha1sum >/dev/null; then sha1sum "$1" | cut -d' ' -f1; else shasum -a 1 "$1" | cut -d' ' -f1; fi; }
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  DATA="${PRISM_DATA:-$HOME/Library/Application Support/PrismLauncher}"
  OPEN="open"
  if [ -z "${SKIP_INSTALL:-}" ] && [ ! -d "/Applications/Prism Launcher.app" ] && [ ! -d "$HOME/Applications/Prism Launcher.app" ]; then
    say "Installing Prism Launcher with Homebrew"
    command -v brew >/dev/null || { echo "Homebrew is missing. Install Prism from https://prismlauncher.org, then run this again."; exit 1; }
    brew install --cask prismlauncher
  fi
elif [ "$OS" = "Linux" ]; then
  OPEN="xdg-open"
  FLATDATA="$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"
  if [ -z "${SKIP_INSTALL:-}" ] && ! command -v prismlauncher >/dev/null && ! { command -v flatpak >/dev/null && flatpak info org.prismlauncher.PrismLauncher >/dev/null 2>&1; }; then
    command -v flatpak >/dev/null || { echo "Install Prism from https://prismlauncher.org (or your package manager), then run this again."; exit 1; }
    say "Installing Prism Launcher with Flatpak"
    flatpak install -y flathub org.prismlauncher.PrismLauncher
  fi
  if [ -n "${PRISM_DATA:-}" ]; then DATA="$PRISM_DATA"
  elif command -v flatpak >/dev/null && flatpak info org.prismlauncher.PrismLauncher >/dev/null 2>&1; then DATA="$FLATDATA"
  else DATA="${XDG_DATA_HOME:-$HOME/.local/share}/PrismLauncher"; fi
else
  echo "Unsupported system: $OS (on Windows use join.ps1)"; exit 1
fi

if pgrep -x prismlauncher >/dev/null 2>&1; then echo "Close Prism Launcher first, then run this again (it would overwrite the changes)."; exit 1; fi
DIR="$DATA/instances/$INSTANCE"
MC="$DIR/.minecraft"
MODS="$MC/mods"
say "Creating instance in $DIR"
mkdir -p "$MODS"
CFG="$DIR/instance.cfg"
if [ ! -f "$CFG" ]; then
  printf '%s\n' "InstanceType=OneSix" "iconKey=default" "name=$INSTANCE" > "$CFG"
else
  echo "Instance already exists; refreshing its versions and launch command."
fi
printf '%s\n' "$MC_PACK" > "$DIR/mmc-pack.json"
# Prism 11 keeps the quotes literally, so write the command with plain quotes and no outer quotes or backslashes.
{ grep -v -e '^PreLaunchCommand=' -e '^OverrideCommands=' "$CFG" || true
  echo "OverrideCommands=true"
  echo "PreLaunchCommand=\"\$INST_JAVA\" -jar packwiz-installer-bootstrap.jar $PACK_URL"; } > "$CFG.new"
mv "$CFG.new" "$CFG"

say "Downloading the mod sync tool"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
curl -fsSL "$BOOT_URL" -o "$TMP"
if command -v sha256sum >/dev/null; then GOT="$(sha256sum "$TMP" | cut -d' ' -f1)"; else GOT="$(shasum -a 256 "$TMP" | cut -d' ' -f1)"; fi
[ "$GOT" = "$BOOT_SHA" ] || { echo "Checksum mismatch for the sync tool; stopping."; exit 1; }
cp "$TMP" "$MC/packwiz-installer-bootstrap.jar"

if [ ! -f "$MC/servers.dat" ]; then
  say "Adding the server to your server list"
  printf '%s' "$SERVERS_B64" | base64 -d > "$MC/servers.dat"
fi

# hand_download LABEL PAGE FILE SHA1 REQUIRED(1/0)
hand_download() {
  local label="$1" page="$2" file="$3" want="$4" req="$5" dest="$MODS/$3" hit="" i
  if [ -f "$dest" ] && [ "$(sha1 "$dest")" = "$want" ]; then echo "$label is already in place."; return 0; fi
  find_dl() { ls -t "$HOME/Downloads/${file%.jar}"*.jar 2>/dev/null | head -n1 || true; }
  hit="$(find_dl)"
  if [ -z "$hit" ]; then
    say "$label has to be downloaded by hand (its author does not allow automatic downloads)."
    echo "Opening $page"
    echo "Click Download and save $file to your Downloads folder. Waiting up to 5 minutes..."
    "$OPEN" "$page" >/dev/null 2>&1 || true
    for i in $(seq 1 100); do sleep 3; hit="$(find_dl)"; [ -n "$hit" ] && break; done
  fi
  if [ -n "$hit" ]; then
    sleep 2
    if [ "$(sha1 "$hit")" = "$want" ]; then cp "$hit" "$dest"; echo "$label added."; return 0; fi
    echo "$(basename "$hit") in Downloads is not the expected file; skipped it."
  fi
  if [ "$req" = 1 ]; then echo "WARNING: $label is still missing. You can't join until $file is in $MODS (re-run this script after downloading it)."
  else echo "$label skipped. To add it later, download $file from $page and drop it into $MODS"; fi
}

say "Done."
echo "Next: open Prism Launcher, add your Microsoft account (Accounts, top right), pick the 'The Gang Survival' instance and press Play."
echo "The first launch downloads the mods (a few minutes). Server: dorkunify.duckdns.org:25567"
