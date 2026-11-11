# The Gang Survival: one-step setup for Prism Launcher on Windows.
# Installs Prism (if missing), creates or refreshes the "The Gang Survival" instance (Minecraft 1.20.1, Fabric 0.20.1),
# wires up the automatic mod sync, and adds the server to the server list. You still sign in with Microsoft inside Prism.
# Safe to re-run. It only touches Prism's own folder (and reads your Downloads folder for hand-downloaded files).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Instance = 'The Gang Survival'
$PackUrl = 'https://raw.githubusercontent.com/loswastaken/the-gang-survival-pack/main/pack.toml'
$BootUrl = 'https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar'
$BootSha = 'a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c'
$ServersB64 = 'CgAACQAHc2VydmVycwoAAAACCAACaXAAG2Rvcmt1bmlmeS5kdWNrZG5zLm9yZzoyNTU2NwgABG5hbWUAEVRoZSBHYW5nIFN1cnZpdmFsAAgAAmlwABExMC4yNC40LjE0MzoyNTU2NwgABG5hbWUAHFRoZSBHYW5nIFN1cnZpdmFsIChob21lL1ZQTikAAA=='
$McPack = '{"components":[{"cachedName":"Minecraft","cachedVersion":"1.20.1","important":true,"uid":"net.minecraft","version":"1.20.1"},{"cachedName":"Intermediary Mappings","cachedVersion":"1.20.1","dependencyOnly":true,"uid":"net.fabricmc.intermediary","version":"1.20.1"},{"cachedName":"Fabric Loader","cachedVersion":"0.20.1","uid":"net.fabricmc.fabric-loader","version":"0.20.1"}],"formatVersion":1}'

function Say($m) { Write-Host ""; Write-Host "==> $m" }
$Data = if ($env:PRISM_DATA) { $env:PRISM_DATA } else { Join-Path $env:APPDATA 'PrismLauncher' }
$utf8 = New-Object System.Text.UTF8Encoding $false
function Get-HandDownload($Label, $Page, $File, $Sha1, $Required) {
    $dest = Join-Path $Mods $File
    if ((Test-Path $dest) -and ((Get-FileHash -Algorithm SHA1 $dest).Hash.ToLower() -eq $Sha1)) { Write-Host "$Label is already in place."; return }
    $dlDir = Join-Path $env:USERPROFILE 'Downloads'
    $find = { Get-ChildItem -Path $dlDir -Filter '*.jar' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ($File -replace '\.jar$', '*.jar') } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
    $hit = & $find
    if (-not $hit) {
        Say "$Label has to be downloaded by hand (its author does not allow automatic downloads)."
        Write-Host "Opening $Page"
        Write-Host "Click Download and save $File to your Downloads folder. Waiting up to 5 minutes..."
        Start-Process $Page
        $deadline = (Get-Date).AddMinutes(5)
        while (-not $hit -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 3; $hit = & $find }
    }
    if ($hit) {
        Start-Sleep -Seconds 2
        if ((Get-FileHash -Algorithm SHA1 $hit.FullName).Hash.ToLower() -eq $Sha1) {
            Copy-Item -Force $hit.FullName $dest
            Write-Host "$Label added."
            return
        }
        Write-Host "$($hit.Name) in Downloads is not the expected file; skipped it."
    }
    if ($Required) { Write-Host "WARNING: $Label is still missing. You can't join until $File is in $Mods (re-run this script after downloading it)." }
    else { Write-Host "$Label skipped. To add it later, download $File from $Page and drop it into $Mods" }
}
$installed = (Test-Path (Join-Path $env:LOCALAPPDATA 'Programs\PrismLauncher\prismlauncher.exe')) -or (Test-Path (Join-Path $Data 'prismlauncher.cfg'))
if (-not $env:SKIP_INSTALL -and -not $installed) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is missing. Install Prism from https://prismlauncher.org, then run this again.'
    }
    Say 'Installing Prism Launcher with winget'
    winget install --id PrismLauncher.PrismLauncher -e --accept-source-agreements --accept-package-agreements
}

if (Get-Process -Name prismlauncher -ErrorAction SilentlyContinue) { throw 'Close Prism Launcher first, then run this again (it would overwrite the changes).' }
$Dir = Join-Path $Data "instances\$Instance"
$Mc = Join-Path $Dir '.minecraft'
$Mods = Join-Path $Mc 'mods'
Say "Creating instance in $Dir"
New-Item -ItemType Directory -Force -Path $Mods | Out-Null
$cfgPath = Join-Path $Dir 'instance.cfg'
if (Test-Path $cfgPath) {
    Write-Host 'Instance already exists; refreshing its versions and launch command.'
    $lines = @(Get-Content $cfgPath | Where-Object { $_ -notmatch '^(PreLaunchCommand|OverrideCommands)=' })
} else {
    $lines = @('InstanceType=OneSix', 'iconKey=default', "name=$Instance")
}
[IO.File]::WriteAllText((Join-Path $Dir 'mmc-pack.json'), $McPack + "`n", $utf8)
# Prism 11 keeps the quotes literally, so write the command with plain quotes and no outer quotes or backslashes.
$lines += 'OverrideCommands=true'
$lines += ('PreLaunchCommand="$INST_JAVA" -jar packwiz-installer-bootstrap.jar ' + $PackUrl)
[IO.File]::WriteAllText($cfgPath, (($lines -join "`n") + "`n"), $utf8)

Say 'Downloading the mod sync tool'
$tmp = Join-Path $env:TEMP 'packwiz-installer-bootstrap.jar'
Invoke-WebRequest -UseBasicParsing -Uri $BootUrl -OutFile $tmp
$got = (Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLower()
if ($got -ne $BootSha) { Remove-Item $tmp -Force; throw 'Checksum mismatch for the sync tool; stopping.' }
Move-Item -Force $tmp (Join-Path $Mc 'packwiz-installer-bootstrap.jar')

$servers = Join-Path $Mc 'servers.dat'
if (-not (Test-Path $servers)) {
    Say 'Adding the server to your server list'
    [IO.File]::WriteAllBytes($servers, [Convert]::FromBase64String($ServersB64))
}

Say 'Done.'
Write-Host "Next: open Prism Launcher, add your Microsoft account (Accounts, top right), pick the 'The Gang Survival' instance and press Play."
Write-Host 'The first launch downloads the mods (a few minutes). Server: dorkunify.duckdns.org:25567'
