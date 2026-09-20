# EndeavourOS Baseline Deployment

A single, idempotent script that takes a fresh EndeavourOS install (GNOME, Wayland) to a fully provisioned baseline: base tooling, the shared app loadout, Wayland tuning, and a split-phase update workflow with GNOME launchers.

Full background and rationale: [EndeavourOS-Deployment-Guide.md](./EndeavourOS-Deployment-Guide.md)

## Prerequisites

- EndeavourOS already installed (GNOME desktop environment, **Btrfs filesystem**, LUKS encryption recommended)
- Mirror list optimised via `reflector` **during the live install**, before running Calamares — this is a separate step that happens before you ever boot into the system this script runs on. See the deployment guide,

 Phase 1.

## Usage

```bash
git clone https://github.com/GrimDaTrashPanda/endeavouros-deploy.git
cd endeavouros-deploy
chmod +x deploy.sh
./deploy.sh
```

Run as your normal user, not root — it calls `sudo` internally where needed.

## What it does

1. Detects CPU vendor (Intel/AMD) and installs the matching microcode package
2. Installs base tooling (git, base-devel, flatpak, fastfetch, duf, tldr, glances, p7zip)
3. Adds the Flathub remote
4. Installs the app loadout from clone-panda-msi (native apps plus its whole Flathub list)
6. Sets `MOZ_ENABLE_WAYLAND=1` for native Firefox/Mozilla Wayland rendering
7. Creates `update-core.sh` / `update-apps.sh` scripts and matching GNOME launchers for the split-update workflow
8. Installs Btrfs snapshot tooling (snapper, snap-pac, grub-btrfs) — auto-snapshots on every pacman transaction, bootable from GRUB if an update breaks things

## After running

- Log out and back in (applies the Wayland env var)
- Set the Wayland flag manually in each Chromium browser — `chrome://flags/#ozone-platform-hint`, `brave://flags/#ozone-platform-hint` — switch to **Wayland**, relaunch. One-time per browser, not automatable from a script since it's stored in each browser's own profile.
- Press **Super**, search "Update" — confirm both launchers appear

## Safe to re-run

Everything uses `--needed`/idempotent checks. Re-running after adding new packages to the script, or on a system that's already partially provisioned, won't duplicate work or error out.

## Customizing for a different machine

Edit the `PACKAGES` array in `deploy.sh` for base tooling. Apps come from [clone-panda-msi](https://github.com/GrimDaTrashPanda/clone-panda-msi), so change them there.
