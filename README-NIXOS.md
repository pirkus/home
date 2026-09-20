# arch-desktop NixOS migration

This bundle targets the desktop machine: Intel i9, 64 GB RAM, NVIDIA RTX 3080 12 GB. It provides both i3/X11 and Hyprland/Wayland sessions.

## Important design points

- The ZIP is standalone. Home Manager reads its dotfiles from the canonical `nixos/home/dotfiles` directory.
- `hardware-configuration.nix` intentionally starts as a fail-fast placeholder. The fresh installer replaces it with hardware detection before partitioning; it omits filesystem declarations because Disko declares them.
- The `filken` account intentionally has no password embedded in Git. The installation wrapper runs `passwd filken` inside the newly installed system before you reboot.
- The fresh installer leaves every non-selected internal drive untouched; removable and extra data disks are available through UDisks/udiskie. The manually mounted flow can additionally generate stable UUID-based systemd automounts for existing data filesystems.
- i3 and Hyprland are both available in tuigreet. The monitor setup does not depend on the old `DP-4` connector name.

## Fresh whole-disk installation (recommended)

Boot the NixOS installer in **UEFI mode**, connect to the network, extract this ZIP somewhere in the installer environment, and run:

```bash
./nixos/scripts/install-from-scratch.sh
```

The script lists writable non-removable physical disks with their model, serial number, transport, partitions, and mount points. It never selects a default. After choosing a disk it resolves it to a stable `/dev/disk/by-id/...` path, refuses mounted disks or disks with active swap, and requires an exact destructive confirmation.

The confirmed disk is erased and receives this layout:

- 1 GiB FAT32 EFI System Partition mounted at `/boot`
- 16 GiB swap partition (ordinary swap; this layout does **not** support hibernation)
- remaining capacity as Btrfs, using `@root`, `@home`, `@nix`, and `@snapshots` subvolumes with Zstandard compression

The remaining internal drives are left untouched. The installer uses the pinned Disko configuration, writes a normal UEFI boot entry, and copies the generated configuration to `/home/filken/nixos-config` in the installed system. It asks for the `filken` password before it permits a reboot.

## Manually partitioned installation

Boot the NixOS installer, partition the target disk, and mount the target root at `/mnt`. Mount the EFI System Partition at the boot mount point expected by your layout (normally `/mnt/boot`).

Extract this ZIP somewhere in the installer environment, enter the extracted directory, then run:

```bash
./nixos/scripts/install-arch-desktop.sh /mnt
```

The wrapper performs these steps in order:

1. Verifies `/mnt` is actually a mount point.
2. Runs `nixos-generate-config` and replaces the hardware placeholder.
3. Verifies the generated hardware file contains a `/` filesystem.
4. Generates internal-drive automount configuration.
5. Builds `path:.#nixosConfigurations.arch-desktop.config.system.build.toplevel` as a safety gate. The explicit path reference keeps a standalone bundle usable even when it sits inside an unrelated Git worktree.
6. Runs `nixos-install --root /mnt --flake path:.#arch-desktop`.
7. Runs `nixos-enter --root /mnt -c 'passwd filken'` and requires you to set the graphical-login password before rebooting.

Only reboot after the `filken` password has been set successfully.

## Manual equivalent

If you prefer to execute each step yourself:

```bash
./nixos/scripts/prepare-arch-desktop.sh /mnt
./nixos/scripts/validate-bundle.sh
nix build 'path:.#nixosConfigurations.arch-desktop.config.system.build.toplevel'
sudo nixos-install --root /mnt --flake 'path:.#arch-desktop'
sudo nixos-enter --root /mnt -c 'passwd filken'
```

The NixOS manual explicitly notes that declaratively-created users have no password by default and recommends setting the user's password with `nixos-enter` before rebooting.

## If merging into pirkus/home

You can still overlay this bundle onto the `arch-desktop` branch of `pirkus/home`. Put Home Manager-managed dotfiles in `nixos/home/dotfiles`.

The included scripts use an explicit `path:` flake reference, so a standalone extracted bundle is not filtered through an unrelated parent Git worktree. When the files are merged into the real repository, they should still be committed normally.

## Reproducible inputs

The bundle should contain a committed `flake.lock` before final installation. If it is absent, generate it once after installing the Nix CLI:

```bash
nix flake lock path:.
```

Review and intentionally update pinned inputs later with `nix flake update path:.`, followed by a full build.

On a non-NixOS host, the Nix CLI may require `experimental-features = nix-command flakes` in `/etc/nix/nix.conf`. The NixOS configuration enables those features for the installed system.

## YubiKey

YubiKey authentication remains optional until enrollment. Password login works first. After booting successfully, plug in the key and generate `/etc/u2f_mappings`, then test it before relying on it:

```bash
nix shell nixpkgs#pam_u2f -c sh -c 'pamu2fcfg | sudo tee /etc/u2f_mappings'
nix shell nixpkgs#pamtester -c pamtester sudo filken authenticate
```

The PAM policy is `sufficient`, so a missing or failed U2F credential falls through to password authentication.

## Validation

A lightweight static check is included:

```bash
./nixos/scripts/validate-bundle.sh
```

The real validation gate is still the Nix build itself:

```bash
nix flake check path:.
nix build 'path:.#nixosConfigurations.arch-desktop.config.system.build.toplevel'
```
