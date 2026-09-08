#!/bin/bash
#
# Runner Launcher - one-command bootstrap (macOS / Linux).
#
# For a NEW user who does not have the app locally yet. Downloads the prebuilt
# app (a runtime-only tarball) from the PUBLIC releases repo and runs the
# installer (runtime deps + native host). No git, no gh, no GitHub account
# needed — the source lives in a separate private repo; only the built app is
# published publicly.
#
# Run it directly:
#   curl -fsSL https://raw.githubusercontent.com/yuriiluchyshyn/workspace-script-manager-releases/main/bootstrap.sh | bash
#
# Override the install location with WSM_HOME=/some/path.

set -u

RELEASES_REPO="yuriiluchyshyn/workspace-script-manager-releases"
ASSET="runner-app.tar.gz"
TARBALL_URL="https://github.com/${RELEASES_REPO}/releases/latest/download/${ASSET}"
APP_DIR="${WSM_HOME:-$HOME/.workspace-script-manager}"

echo "Runner Launcher bootstrap"
echo "Install location: $APP_DIR"

# --- required tools ----------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found. Install curl and re-run this command."
  exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
  echo "tar not found. Install tar and re-run this command."
  exit 1
fi

# --- download ----------------------------------------------------------------
TMP_TARBALL="$(mktemp -t runner-app.XXXXXX).tar.gz"
cleanup() { rm -f "$TMP_TARBALL"; }
trap cleanup EXIT

echo "Downloading latest app..."
if ! curl -fSL "$TARBALL_URL" -o "$TMP_TARBALL"; then
  echo "Download failed: $TARBALL_URL"
  echo "Make sure a release has been published to $RELEASES_REPO."
  exit 1
fi

# --- extract -----------------------------------------------------------------
mkdir -p "$APP_DIR"
echo "Extracting to $APP_DIR..."
# Clean the install dir so nothing but the runtime tarball's contents remain
# (removes leftover source like src/, public/, examples/ from older installs).
# node_modules is kept to avoid a slow reinstall; user data lives in ~/runner-yl.
find "$APP_DIR" -mindepth 1 -maxdepth 1 ! -name 'node_modules' -exec rm -rf {} +
if ! tar -xzf "$TMP_TARBALL" -C "$APP_DIR"; then
  echo "Extraction failed."
  exit 1
fi

# --- install -----------------------------------------------------------------
INSTALLER="$APP_DIR/desktop-launcher/install-macos.sh"
if [ ! -f "$INSTALLER" ]; then
  echo "Installer not found at $INSTALLER"
  exit 1
fi
echo "Running installer..."
exec bash "$INSTALLER"
