# EndeavourOS Baseline Deployment Guide

> Universal setup reference for any hardware — from live ISO to fully configured system  
> Arch-based · GNOME · Wayland · Multi-browser · Split-update workflow

---

## Table of Contents

1. [Overview](#1-overview)
2. [Phase 1: Installation](#2-phase-1-installation)
3. [Phase 2: Wayland Input Configuration](#3-phase-2-wayland-input-configuration)
4. [Phase 3: Software Provisioning](#4-phase-3-software-provisioning)
5. [Phase 4: Split-Phase Update Workflow](#5-phase-4-split-phase-update-workflow)
6. [Phase 5: Ongoing Maintenance Reference](#6-phase-5-ongoing-maintenance-reference)
7. [Quick Reference Card](#7-quick-reference-card)
8. [Appendix: Troubleshooting](#8-appendix-troubleshooting)

---

## 1. Overview

This document is the canonical reference for deploying EndeavourOS from scratch on any reasonably modern x86-64 machine. It covers everything from live installer quirks through post-install configuration, browser stack provisioning, and a split-phase update workflow designed to keep browsers running even while the rest of the system upgrades.

The guide is written for competent users — you should be comfortable opening a terminal and running commands — but it does not assume you have memorized Arch conventions. Every command is explained so you understand what it does, not just that you should do it.

**This guide covers:**

| ✅ In scope | ❌ Out of scope |
|---|---|
| EndeavourOS installation via Calamares | Dual-boot or multi-partition layouts |
| LUKS full-disk encryption | NVIDIA proprietary driver setup |
| Wayland input optimisation for all browser engines | Gaming / Steam configuration |
| Multi-browser AUR provisioning | Server / headless deployments |
| Decoupled split-update workflow | Encrypted home directory (separate from LUKS) |

> 📌 **No debloating here.** GNOME's default app set on EndeavourOS (Weather, Clocks, Calculator, Loupe, Showtime, etc.) is small enough that stripping it buys you nothing meaningful — a few KB of disk and zero noticeable speedup on update cycles. Arch already runs lean. This guide installs what you actually use rather than spending a phase removing things that were never the problem.

---

## 2. Phase 1: Installation

Before launching the graphical installer, fix one potential problem that can silently stall the install at the 36% progress mark.

### 1.1 Mirror List — Do This First

> ⚠️ **Run this before starting the installer.** Open a terminal in the live environment before clicking anything in Calamares.

The Calamares installer can deadlock mid-install if it hits a slow or overloaded mirror during the package download phase. The symptom is the progress bar freezing at around 36% with no obvious error. Pre-generating a fast mirror list prevents this entirely.

In the live environment terminal, run:

```bash
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

**What this does:** Queries the Arch mirror database, tests the 20 most recently synced HTTPS mirrors, ranks them by actual download speed, and writes the result to `/etc/pacman.d/mirrorlist` — the file the installer reads. It only persists for the live session; the installer copies it into the new system during setup.

### 1.2 Running the Installer

1. Boot from the live media and select the **online installer**.
2. Choose **GNOME** as your desktop environment. This matches your standard footprint — GDM as display manager, GNOME Shell as the core experience.
3. Work through the installer screens. Most defaults are fine.
4. On the **Partitions** screen: select **Erase disk** and enable **Encrypt system (LUKS)**. Set a strong passphrase — you will need this on every boot.
5. Set your timezone, locale, and keyboard layout.
6. Create your user account. Check the box to use the same password as root, or set separate ones.
7. Review the summary screen and click **Install**.

> 📌 **Why LUKS encryption?** LUKS encrypts the entire partition before the OS loads. If someone physically removes your drive, they cannot read any files — browser sessions, cached credentials, application databases — without your passphrase. The performance impact on any SSD is negligible.

### 1.3 First Boot

After the installer finishes and you reboot, you will see a passphrase prompt before the GNOME login screen. This is normal — it is LUKS unlocking the drive. Enter your disk passphrase, then log in with your user account.

> ⚠️ **Do not skip the post-install steps.** The system that just booted has the mirror list baked in from Phase 1. Proceed immediately to Phase 2 before installing anything else.

---

## 3. Phase 2: Wayland Input Configuration

EndeavourOS ships with GNOME on Wayland. Most applications work out of the box, but browsers built on two different rendering engines (Mozilla and Chromium) each need a small nudge to use native Wayland rendering instead of falling back to compatibility mode. Without these settings you may see sluggish scrolling, incorrect text selection, or blurry rendering at non-integer zoom levels.

### 2.1 Mozilla Engine — Firefox / LibreWolf

One environment variable enables native Wayland rendering for all Mozilla-engine browsers system-wide. Add it to the global environment file:

```bash
echo "MOZ_ENABLE_WAYLAND=1" | sudo tee -a /etc/environment
```

**What this does:** Appends one line to `/etc/environment`, which is read by the login session on startup. Every user on this machine will benefit. The change takes effect after your next login or reboot.

### 2.2 Chromium Engine — Chrome, Brave, Edge

Chromium-based browsers use a flags system for experimental and platform-specific settings. Each browser must be configured individually — there is no system-wide environment variable that works reliably across all Chromium forks.

For each Chromium-based browser you install:

1. Open the browser and paste the appropriate URL into the address bar:

   | Browser | Address to paste |
   |---|---|
   | Google Chrome | `chrome://flags/#ozone-platform-hint` |
   | Brave | `brave://flags/#ozone-platform-hint` |
   | Microsoft Edge | `edge://flags/#ozone-platform-hint` |

2. Find the **Ozone Platform Hint** setting (it will already be highlighted since the URL targets it directly).
3. Change the dropdown from **Default** to **Wayland**.
4. Click **Relaunch** at the bottom of the screen.

> 📌 **You only do this once per browser.** The flag is saved to that browser's profile and persists across updates.

---

## 4. Phase 3: Software Provisioning

This phase installs your native toolkit, sets up the AUR helper, and provisions the browser stack. The sequence matters — install in the order shown.

### 3.1 Understanding the Arch Package Ecosystem

Arch Linux (and by extension EndeavourOS) pulls software from three distinct sources:

| Source | What it is |
|---|---|
| **Official Repos** (`pacman`) | Curated, pre-built packages maintained by Arch developers. Fast and reliable. |
| **AUR** (Arch User Repository) | Community-maintained build scripts. Your machine compiles from source — or you target a pre-compiled `-bin` variant. |
| **Flatpak** | Sandboxed, distribution-agnostic packages. Fully isolated from system libraries. |

> ⚠️ **Always use `-bin` AUR packages on older or low-power hardware.** Compiling `google-chrome` from source can take 30+ minutes on older CPUs and may OOM on machines under 8 GB RAM. Packages with the `-bin` suffix are pre-compiled upstream binaries repackaged for Arch. They install in seconds and produce identical results.

### 3.2 Native Toolkit — Standard Loadout

This is the package set you run on every full deployment. All of it lives in the official repos — no AUR compilation needed for any of it.

```bash
sudo pacman -S --needed \
  firefox \
  telegram-desktop \
  shotcut \
  gimp \
  glances \
  fastfetch \
  duf \
  tldr \
  flatpak \
  vlc \
  p7zip
```

| Package | What it's for |
|---|---|
| `firefox` | Primary browser, Mozilla engine. |
| `telegram-desktop` | Messaging. |
| `shotcut` | Video editing. |
| `gimp` | Raster image editing / photo work. |
| `glances` | Terminal-based system resource monitor. |
| `fastfetch` | System info display — quick hardware/OS confirmation. |
| `duf` | Disk usage utility, cleaner output than `df`. |
| `tldr` | Simplified man pages / command cheat sheets. |
| `flatpak` | Enables the Flatpak runtime for any sandboxed apps you add later. |
| `vlc` | Media playback. |
| `p7zip` | Archive extraction/creation, including `.7z`. |

> 📌 **This is a starting point, not a mandate.** If a specific machine doesn't need video editing or image work — say, a pure documentation/browsing box — drop `shotcut` and `gimp` from the line. The rest is close to universal across your fleet.

Initialise the Flathub remote so it's ready if you add any sandboxed apps later:

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### 3.3 Hardware-Conditional Packages (Intel Only)

> ⚠️ **Skip this entirely on AMD hardware.** These two packages are Intel-specific and provide no benefit — they simply won't apply — on an AMD CPU.

If the target machine has an **Intel CPU**, also install:

```bash
sudo pacman -S --needed intel-ucode sof-firmware
```

| Package | What it's for |
|---|---|
| `intel-ucode` | Microcode updates for Intel CPUs — security and stability patches applied at boot, before the OS proper loads. |
| `sof-firmware` | Sound Open Firmware, required for audio on many newer Intel laptops using SOF-based audio drivers. Mostly relevant on machines from roughly the last 5-6 years; harmless to include on older hardware like the U430. |

On **AMD** hardware, the equivalent microcode package is `amd-ucode` — install that instead if you want the same boot-time protection.

### 3.4 Install yay (AUR Helper)

`yay` is a command-line wrapper around `pacman` that automates downloading, building, and installing AUR packages. It is itself an AUR package, so you bootstrap it manually once:

```bash
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si
cd ..
```

**What this does:** Clones the `yay-bin` AUR package (a pre-compiled Go binary — no Go toolchain required), builds the minimal wrapper, and installs it. After this you can use `yay` exactly like `pacman` for AUR packages.

> 📌 **`base-devel` and `git` are required for this step.** If you haven't installed them yet, run `sudo pacman -S --needed base-devel git` first — `makepkg` depends on `base-devel`, and cloning the AUR repo depends on `git`.

### 3.5 Browser Stack

Install all three AUR browsers in a single command using pre-compiled `-bin` targets:

```bash
yay -S google-chrome brave-bin microsoft-edge-stable-bin --needed --noconfirm
```

`--needed` skips packages already at the current version. `--noconfirm` suppresses interactive prompts — safe here because all three are well-established `-bin` targets with no custom build decisions.

> ✅ **After install:** Go back to Phase 2.2 and configure the Wayland flag for each browser before using them.

---

## 5. Phase 4: Split-Phase Update Workflow

This is the operational core of the deployment. The idea: system updates and browser/AUR updates are kept deliberately separate so you can always update the base OS without touching browsers — and vice versa. AUR browser updates sometimes lag or temporarily break; you should not be forced to touch a working browser install just because you want system security patches.

### 4.1 Why Split Updates?

| Without split updates | With split updates (this workflow) |
|---|---|
| Updates everything at once — AUR + official repos | Updates official repos independently from AUR/Flatpak |
| A broken AUR package blocks the whole update | Broken AUR package does not affect core system updates |
| Harder to isolate what caused a breakage | Easy to isolate — core vs. application layer is always distinct |
| One command | Two launcher icons — still simple to use |

### 4.2 Automated Setup Script

Run the following block in a terminal. It creates the two update scripts, marks them executable, detects your terminal emulator, and creates GNOME application launcher entries for both. Paste the entire block at once:

```bash
# Create local bin and applications directories if they don't exist
mkdir -p ~/.local/bin ~/.local/share/applications

# ─────────────────────────────────────────────────────────────
# PHASE 4A: Core system updater (official repos only)
# ─────────────────────────────────────────────────────────────
cat << 'EOF' > ~/.local/bin/update-core.sh
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING OFFICIAL ARCH REPOSITORIES"
echo "========================================="
echo "==> Isolating foreign (AUR) packages..."
FOREIGN_PKGS=$(pacman -Qmq | tr '\n' ',' | sed 's/,$//')
if [ -n "$FOREIGN_PKGS" ]; then
    sudo pacman -Syu --ignore "$FOREIGN_PKGS"
else
    sudo pacman -Syu
fi
echo ""
echo "==> Checking for config drift (.pacnew files)..."
find /etc -name "*.pacnew" 2>/dev/null
echo ""
echo "Press Enter to close..."
read -r
EOF

# ─────────────────────────────────────────────────────────────
# PHASE 4B: Application layer updater (Flatpak + AUR)
# ─────────────────────────────────────────────────────────────
cat << 'EOF' > ~/.local/bin/update-apps.sh
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING FLATPAKS & AUR PACKAGES"
echo "========================================="
echo "==> Updating Flatpaks..."
flatpak update -y
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
EOF

# Mark both scripts executable
chmod +x ~/.local/bin/update-core.sh ~/.local/bin/update-apps.sh

# ─────────────────────────────────────────────────────────────
# Detect terminal emulator
# ─────────────────────────────────────────────────────────────
if command -v gnome-terminal &> /dev/null; then
    TERM_EXEC="gnome-terminal --"
elif command -v kgx &> /dev/null; then
    TERM_EXEC="kgx -e"
else
    TERM_EXEC="bash -c"
fi

# ─────────────────────────────────────────────────────────────
# Create GNOME application launcher: Core updater
# ─────────────────────────────────────────────────────────────
cat << EOF > ~/.local/share/applications/update-system.desktop
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

# ─────────────────────────────────────────────────────────────
# Create GNOME application launcher: App layer updater
# ─────────────────────────────────────────────────────────────
cat << EOF > ~/.local/share/applications/update-apps.desktop
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

# Refresh GNOME application database
update-desktop-database ~/.local/share/applications/
echo "Done. Press Super and search 'Update' to verify launchers."
```

> 📌 **Why `gnome-terminal`/`kgx` detection over a flat `Terminal=true`?** Relying on GNOME's "open in terminal" flag depends on a default terminal app being correctly registered on that system. Explicitly detecting and invoking the terminal binary is more portable across fresh installs where that default hasn't been set yet.

### 4.3 Verifying the Launchers

1. Press the **Super** key to open the GNOME Activities overview.
2. Type **Update** in the search bar.
3. You should see two entries: **Update System (Core Only)** and **Update Apps (Flatpak & AUR)**.
4. Click each one to confirm it opens a terminal window and begins running. Both will prompt for your sudo password on first run.

> ✅ **Recommended cadence:** Run **Update System (Core Only)** weekly for security patches and kernel updates. Run **Update Apps (Flatpak & AUR)** separately, when you are not actively using the browsers being updated — AUR browser updates occasionally require a relaunch.

---

## 6. Phase 5: Ongoing Maintenance Reference

Common post-deployment tasks. Refer here when something needs attention.

### 5.1 Handling .pacnew Files

When a package update includes a modified default config file that would overwrite one you have customised, pacman saves the new version with a `.pacnew` suffix instead of overwriting yours. The `update-core` script reports any it finds.

```bash
# List all pending .pacnew files
find /etc -name "*.pacnew" 2>/dev/null

# Compare your version against the new default (example)
diff /etc/ssh/sshd_config /etc/ssh/sshd_config.pacnew
```

Review the diff, merge any needed changes into your existing config, then delete the `.pacnew` file. Leaving them to accumulate is harmless but sloppy — each one represents a config divergence you should review.

### 5.2 Orphaned Package Cleanup

Packages installed as dependencies but no longer needed by anything accumulate over time:

```bash
# List orphaned packages
pacman -Qdtq

# Remove them (if the list looks reasonable)
sudo pacman -Rns $(pacman -Qdtq)
```

> ⚠️ **Review the list before removing.** Occasionally a package you intentionally installed shows up as an orphan because nothing else depends on it.

### 5.3 Mirror Refresh

```bash
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

Do this after moving to a different region, if updates start feeling slow, or after a major Arch infrastructure event.

### 5.4 Checking Foreign (AUR) Package List

```bash
pacman -Qm
```

Lists all packages installed from outside the official repos. On a standard deployment, this should show exactly `brave-bin`, `google-chrome`, `microsoft-edge-stable-bin`, and `yay` (plus `yay-bin` if it wasn't replaced) — nothing else. This is also what `update-core` uses to build its ignore list, so any AUR packages you add later are automatically excluded from core updates.

---

## 7. Quick Reference Card

| Task | Command |
|---|---|
| Refresh mirrors | `reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist` |
| Update official repos only | `sudo pacman -Syu --ignore $(pacman -Qmq \| tr '\n' ',' \| sed 's/,$//')` |
| Update AUR packages only | `yay -Sua` |
| Update Flatpaks only | `flatpak update -y` |
| Install official package | `sudo pacman -S <package>` |
| Install AUR package | `yay -S <package>` |
| Remove package + dependencies | `sudo pacman -Rns <package>` |
| List AUR / foreign packages | `pacman -Qm` |
| List explicitly installed packages | `pacman -Qet` |
| List orphaned packages | `pacman -Qdtq` |
| Find .pacnew files | `find /etc -name '*.pacnew'` |
| Check installed package info | `pacman -Qi <package>` |
| Search repos for a package | `pacman -Ss <search term>` |

---

## 8. Appendix: Troubleshooting

### A.1 Installer Stalls at 36%

You skipped or did not finish the reflector step. Cancel the install, reboot the live environment, run the reflector command, then restart the installer.

### A.2 LUKS Passphrase Prompt Not Appearing on Boot

This usually means the bootloader is not configured for encrypted root. Boot from the live USB, mount your encrypted partition, chroot in, and verify that your initramfs includes the `encrypt` hook and your bootloader has the correct `cryptdevice=` kernel parameter. Full recovery details: [wiki.archlinux.org/title/dm-crypt](https://wiki.archlinux.org/title/dm-crypt).

### A.3 Browser Scrolling Still Feels Wrong After Phase 2

Verify the flag was saved by reopening the flags page and checking the dropdown. If it shows Wayland but scrolling is still off, log out and back in to ensure `/etc/environment` has been applied. If problems persist on a Chromium browser, try adding `--ozone-platform=wayland` to the browser's `.desktop` file `Exec=` line as a workaround.

### A.4 yay Not Found After Install

The `~/.local/bin` directory may not be on your PATH. Check with `echo $PATH`. If it is missing, add the following to `~/.bashrc` or `~/.zshrc` and re-source it:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### A.5 Update Launchers Not Appearing in GNOME

Run the database refresh manually:

```bash
update-desktop-database ~/.local/share/applications/
```

Then log out and back in. If they still do not appear, verify the files exist:

```bash
ls ~/.local/share/applications/update-*.desktop
```

---

*EndeavourOS Baseline Deployment Guide · Arch-based · GNOME · Wayland*
