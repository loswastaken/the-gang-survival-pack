# The Gang Survival pack

packwiz pack for Los's "The Gang Survival" server: Minecraft 1.20.1, Fabric Loader 0.20.1, with Sodium 0.5.13 (client only, for performance). The server is Paper with server-side plugins only, so no other mods are needed. Links only, no mod files.

Server: `dorkunify.duckdns.org:25567` (at home or on the VPN: `10.24.4.143:25567`). Whitelisted players only; send Los your Minecraft username first.

## Quick setup (one command)
Close Prism Launcher first.

Windows (PowerShell):

    irm https://raw.githubusercontent.com/loswastaken/the-gang-survival-pack/main/join.ps1 | iex

macOS / Linux:

    curl -fsSL https://raw.githubusercontent.com/loswastaken/the-gang-survival-pack/main/join.sh | bash

It installs Prism Launcher if needed, creates (or refreshes) the "The Gang Survival" instance, sets up the mod sync and adds the server. Then open Prism, sign in with your Microsoft account, and press Play. Read `join.ps1` / `join.sh` first if you like; they only touch Prism's own folder.

## Manual setup
1. Create a Prism instance named "The Gang Survival": Minecraft 1.20.1, Fabric Loader 0.20.1 (Java 17).
2. Download https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar into the instance's `.minecraft` folder.
3. Instance Settings > Custom commands > Pre-launch command:
   `"$INST_JAVA" -jar packwiz-installer-bootstrap.jar https://raw.githubusercontent.com/loswastaken/the-gang-survival-pack/main/pack.toml`
4. Launch. Mods sync on every launch.
