<#
  Runner Launcher - one-command bootstrap (Windows).

  For a NEW user who does not have the app locally yet. Downloads the prebuilt
  app (a runtime-only tarball) from the PUBLIC releases repo and runs the
  installer (runtime deps + native host). No git, no gh, no GitHub account
  needed — the source lives in a separate private repo; only the built app is
  published publicly.

  Run it directly:
    irm https://raw.githubusercontent.com/yuriiluchyshyn/workspace-script-manager-releases/main/bootstrap.ps1 | iex

  Override the install location with $env:WSM_HOME.
#>

$ErrorActionPreference = 'Stop'

$ReleasesRepo = 'yuriiluchyshyn/workspace-script-manager-releases'
$Asset        = 'runner-app.tar.gz'
$TarballUrl   = "https://github.com/$ReleasesRepo/releases/latest/download/$Asset"
$AppDir       = if ($env:WSM_HOME) { $env:WSM_HOME } else { Join-Path $env:USERPROFILE '.workspace-script-manager' }

Write-Host 'Runner Launcher bootstrap'
Write-Host "Install location: $AppDir"

# --- required tools ----------------------------------------------------------
# Windows 10 (1803+) and Windows 11 ship bsdtar as `tar`. Bail early if absent.
if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  Write-Error 'tar not found. Windows 10 1803+ includes it; update Windows or install bsdtar, then re-run.'
  exit 1
}

# --- download ----------------------------------------------------------------
$TmpTarball = Join-Path $env:TEMP "runner-app-$([guid]::NewGuid().ToString('N')).tar.gz"
try {
  Write-Host 'Downloading latest app...'
  Invoke-WebRequest -Uri $TarballUrl -OutFile $TmpTarball -UseBasicParsing
} catch {
  Write-Error "Download failed: $TarballUrl. Make sure a release has been published to $ReleasesRepo."
  exit 1
}

# --- extract -----------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
Write-Host "Extracting to $AppDir..."
# Clean the install dir so nothing but the runtime tarball's contents remain
# (removes leftover source from older installs). node_modules is kept to avoid a
# slow reinstall; user data lives in %USERPROFILE%\runner-yl.
Get-ChildItem -Force -LiteralPath $AppDir |
  Where-Object { $_.Name -ne 'node_modules' } |
  ForEach-Object { Remove-Item -Recurse -Force -LiteralPath $_.FullName }
& tar -xzf $TmpTarball -C $AppDir
if ($LASTEXITCODE -ne 0) {
  Remove-Item -Force $TmpTarball -ErrorAction SilentlyContinue
  Write-Error 'Extraction failed.'
  exit 1
}
Remove-Item -Force $TmpTarball -ErrorAction SilentlyContinue

# --- install -----------------------------------------------------------------
$installer = Join-Path $AppDir 'desktop-launcher\install-windows.ps1'
if (-not (Test-Path $installer)) {
  Write-Error "Installer not found at $installer"
  exit 1
}
Write-Host 'Running installer...'
& powershell -NoProfile -ExecutionPolicy Bypass -File $installer
