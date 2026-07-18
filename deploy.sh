#!/usr/bin/env bash
#
# EndeavourOS Baseline Deployment Script
# https://github.com/<your-username>/<your-repo>
#
# Run this AFTER first boot into your installed EndeavourOS system.
# Mirror list optimisation (the 36% installer stall fix) happens during
# the live install itself and is NOT part of this script — see the
# README / deployment guide for that step.
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Safe to re-run. Uses --needed everywhere so already-installed
# packages are skipped rather than reinstalled.

set -euo pipefail

# ── Colour output helpers ────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${BOLD}${GREEN}==>${RESET} $1"; }
warn()  { echo -e "${BOLD}${YELLOW}==>${RESET} $1"; }
error() { echo -e "${BOLD}${RED}==>${RESET} $1" >&2; }

# ── Sanity checks ─────────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
  error "Don't run this as root. Run as your normal user — it calls sudo where needed."
  exit 1
fi

if ! command -v pacman &> /dev/null; then
  error "pacman not found. This script is for Arch-based systems (EndeavourOS, Arch, Manjaro, etc.)."
  exit 1
fi

echo ""
echo -e "${BOLD}EndeavourOS Baseline Deployment${RESET}"
echo "──────────────────────────────────────────"
echo ""

# ── Phase 1: CPU vendor detection ─────────────────────────────────────────
info "Detecting CPU vendor..."

CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
UCODE_PKG=""

case "$CPU_VENDOR" in
  GenuineIntel)
    UCODE_PKG="intel-ucode"
    info "Detected: Intel CPU → will install intel-ucode + sof-firmware"
    ;;
  AuthenticAMD)
    UCODE_PKG="amd-ucode"
    info "Detected: AMD CPU → will install amd-ucode"
    ;;
  *)
    warn "Could not determine CPU vendor (got: '${CPU_VENDOR:-unknown}'). Skipping microcode package."
    ;;
esac

echo ""

# ── Phase 2: Native toolkit (official repos only) ────────────────────────
info "Installing native toolkit (official repos)..."

PACKAGES=(
  base-devel
  git
  firefox
  telegram-desktop
  shotcut
  gimp
  glances
  fastfetch
  duf
  tldr
  flatpak
  vlc
  p7zip
)

if [ -n "$UCODE_PKG" ]; then
  PACKAGES+=("$UCODE_PKG")
  if [ "$UCODE_PKG" = "intel-ucode" ]; then
    PACKAGES+=("sof-firmware")
  fi
fi

sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo ""

# ── Phase 3: Flathub remote ───────────────────────────────────────────────
info "Setting up Flathub remote..."

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo ""

# ── Phase 4: AUR helper (yay) ──────────────────────────────────────────────
if command -v yay &> /dev/null; then
  info "yay already installed, skipping bootstrap."
else
  info "Bootstrapping yay (AUR helper)..."
  BUILD_DIR=$(mktemp -d)
  git clone --quiet https://aur.archlinux.org/yay-bin.git "$BUILD_DIR/yay-bin"
  (cd "$BUILD_DIR/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$BUILD_DIR"
fi

echo ""

# ── Phase 5: Browser stack (AUR, pre-compiled -bin targets) ──────────────
info "Installing browser stack (Chrome, Brave, Edge)..."

yay -S --needed --noconfirm google-chrome brave-bin microsoft-edge-stable-bin

echo ""

# ── Phase 6: Wayland environment variable (Firefox/Mozilla engine) ───────
info "Configuring Wayland for Mozilla-engine browsers..."

if grep -q "MOZ_ENABLE_WAYLAND" /etc/environment 2>/dev/null; then
  info "MOZ_ENABLE_WAYLAND already set in /etc/environment, skipping."
else
  echo "MOZ_ENABLE_WAYLAND=1" | sudo tee -a /etc/environment > /dev/null
  info "Added MOZ_ENABLE_WAYLAND=1 to /etc/environment (takes effect next login)."
fi

warn "Chromium browsers (Chrome/Brave/Edge) need their Wayland flag set manually per-browser."
warn "See the deployment guide, Phase 2.2 — one-time, ~10 seconds per browser."

echo ""

# ── Phase 7: Split-update workflow scripts + GNOME launchers ─────────────
info "Setting up split-update workflow..."

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"

# --- Core system updater (official repos only) ---
cat << 'SCRIPT_EOF' > "$HOME/.local/bin/update-core.sh"
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING OFFICIAL ARCH REPOSITORIES"
echo "========================================="
echo "==> Isolating foreign (AUR) packages..."
sudo pacman -Syu
echo ""
echo "==> Checking for config drift (.pacnew files)..."
find /etc -name "*.pacnew" 2>/dev/null
echo ""
echo "Press Enter to close..."
read -r
SCRIPT_EOF

# --- Application layer updater (Flatpak + AUR) ---
cat << 'SCRIPT_EOF' > "$HOME/.local/bin/update-apps.sh"
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING FLATPAKS & AUR PACKAGES"
echo "========================================="
echo "==> Updating Flatpaks..."
if command -v flatpak &> /dev/null; then
    flatpak update -y
fi
echo ""
echo "==> Updating AUR packages..."
if command -v yay &> /dev/null; then
    yay -Sua --noconfirm
elif command -v paru &> /dev/null; then
    paru -Sua --noconfirm
fi
echo ""
echo "Press Enter to close..."
read -r
SCRIPT_EOF

chmod +x "$HOME/.local/bin/update-core.sh" "$HOME/.local/bin/update-apps.sh"

# --- Detect terminal emulator for the .desktop Exec= line ---
if command -v gnome-terminal &> /dev/null; then
    TERM_EXEC="gnome-terminal --"
elif command -v kgx &> /dev/null; then
    TERM_EXEC="kgx -e"
else
    TERM_EXEC="bash -c"
fi

# --- Core updater launcher ---
# NOTE: unquoted heredoc (EOF, not 'EOF') is intentional here — it lets
# $TERM_EXEC and $HOME expand to real values now, since .desktop files
# are static text and never get re-parsed through bash later.
cat << EOF > "$HOME/.local/share/applications/update-system.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Update System (Core Only)
Comment=Updates official repositories while ignoring AUR
Exec=$TERM_EXEC "$HOME/.local/bin/update-core.sh"
Terminal=false
Icon=system-software-update
Categories=System;Settings;
Keywords=update;upgrade;pacman;system;
EOF

# --- App layer updater launcher ---
cat << EOF > "$HOME/.local/share/applications/update-apps.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Update Apps (Flatpak & AUR)
Comment=Updates sandboxed Flatpaks and AUR packages
Exec=$TERM_EXEC "$HOME/.local/bin/update-apps.sh"
Terminal=false
Icon=software-update-available
Categories=System;Settings;
Keywords=update;upgrade;flatpak;aur;apps;
EOF

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true

echo ""
info "Deployment complete."
echo ""
echo "Next steps:"
echo "  1. Log out and back in (applies MOZ_ENABLE_WAYLAND)."
echo "  2. Set the Wayland flag in each Chromium browser (chrome/brave/edge://flags/#ozone-platform-hint)."
echo "  3. Press Super, search 'Update', confirm both launchers appear."
echo ""
