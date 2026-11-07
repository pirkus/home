# arch-desktop NixOS migration

This bundle targets the desktop machine: AMD Ryzen 9 9900X, NVIDIA RTX 5060 Ti and RTX 3080 12 GB. It provides both i3/X11 and Hyprland/Wayland sessions.

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

## AMD hardware

The normal `arch-desktop` configuration now targets the Ryzen 9 9900X, with AMD
microcode and `kvm-amd`. There is no separate AMD specialisation to select;
the normal boot entry is tagged `AMD`. Existing generations remain available
for rollback until explicitly deleted.

The NVIDIA configuration enables the open kernel modules required for the
RTX 5060 Ti (Blackwell), which also support the installed RTX 3080. No GPU PCI
bus IDs are pinned. Connect your display to the GPU you intend to use.

Install the updated default boot configuration from this folder:

```bash
sudo nixos-rebuild boot --flake "path:$PWD#arch-desktop"
```

This prepares the next boot without switching the running system. Reboot into
the newest normal entry. The boot menu waits ten seconds.

A motherboard replacement does not carry over the old board's UEFI boot entries.
Use UEFI mode on the new board and select the existing drive's EFI bootloader;
if necessary, use its boot-from-file option to launch `EFI/BOOT/BOOTX64.EFI` on
the EFI partition. Keep a NixOS installer USB handy for recovery, and back up
important data before swapping hardware. New onboard devices may require
additional configuration after the swap.

## Optional gpu-unlock boot entry

The `gpu-unlock` specialisation targets only the RTX 3080 12 GB at
`0000:03:00.0`. The normal entry keeps stock GPU behavior; the RTX 5060 Ti is
not targeted. Source and NVIDIA firmware inputs are pinned in
`nixos/packages/gpu-unlock.nix`. Firmware is extracted as data; the NVIDIA
installer is not executed and the installed NVIDIA driver is not replaced.

Build and install the boot entries without switching the running system:

```bash
nix build --out-link result-gpu-unlock 'path:.#nixosConfigurations.arch-desktop.config.system.build.toplevel'
sudo nixos-rebuild boot --flake "path:$PWD#arch-desktop"
```

Reboot and choose the entry labelled `gpu-unlock` / `GPU-unlock-3080` to test
the unlock. Choose the normal entry to leave it off. The normal entry remains
the default. To disable it for a single boot of the alternate entry, press `e`
in systemd-boot and remove `gpu_unlock.targets=0000:03:00.0` before booting.
This requires a reboot, not a runtime service toggle.

After booting the alternate entry, check the target and success messages:

```bash
cat /proc/cmdline
journalctl -k -b --grep=gpu_unlock
lspci -Dnnk -s 0000:03:00.0
```

The initrd loads `gpu_unlock` before explicit module loading and udev coldplug,
so NVIDIA binds afterward. If the motherboard/PCI layout changes, recheck the
3080's address before using this entry. Successful image construction does not
prove a hardware unlock or speedup; compare the same Qwen workload after boot.

## YubiKey

YubiKey authentication remains optional until enrollment. Password login works first. After booting successfully, plug in the key and generate `/etc/u2f_mappings`, then test it before relying on it:

```bash
nix shell nixpkgs#pam_u2f -c sh -c 'pamu2fcfg | sudo tee /etc/u2f_mappings'
nix shell nixpkgs#pamtester -c pamtester sudo filken authenticate
```

The PAM policy is `sufficient`, so a missing or failed U2F credential falls through to password authentication.

## Lean development

Home Manager installs Elan, which provides the `lean` and `lake` commands and
manages Lean versions per project through `lean-toolchain` files. After applying
the configuration, set a default toolchain for use outside projects:

```bash
elan default leanprover/lean4:stable
lean --version
lake --version
```

## Local chat and OpenCode acceleration

Open WebUI runs at **http://localhost:3000** using the existing LM Studio server
on `127.0.0.1:1234`. Create the first WebUI account in the browser; that account
becomes its administrator. The UI also accepts LAN connections on port 3000
at `http://<this-computer's-IP>:3000`. Chats and accounts
persist in Docker's `open-webui` volume. The official container is pinned by
version and digest because this nixpkgs revision's native package has a broken
Python dependency.

Both clients use the downloaded `qwen/qwen3.8-27b` Q4_K_M model with 131,072
context tokens, Flash Attention, Q8 key/value cache, full GPU offload across the
two NVIDIA cards, one prediction at a time, and native MTP speculative decoding
with three draft tokens. `qwen-model.service` loads it at boot after llmster;
the existing lingering user manager allows this before graphical login.
Loading without a TTL keeps it resident while idle. Selecting other large
models can consume the VRAM needed by Qwen.

`nixos/scripts/configure-local-ai.py` merges these defaults into LM Studio and
OpenCode, backs up changed files, and preserves existing prompt templates and
other providers. Home Manager reruns it on activation. The current OpenCode
JSONC file contains plain JSON, as required by this merge script. OpenCode uses
low reasoning effort by default, with `low`, `medium`, and `xhigh` variants.
Speculative decoding itself runs in LM Studio and benefits both clients.

A short 256-token coding test with the same prompt, seed, temperature, and low
reasoning effort measured 28.9 tokens/sec without MTP and 48.8 tokens/sec with
MTP. These numbers describe short-prompt generation on this machine, not
generation with a full context window.

A synthetic recall test with 120,080 input tokens correctly returned the marker
placed midway through the prompt. Initial prompt processing took about 129
seconds, with subsequent generation at 25.5 tokens/sec. This verifies one long
request fits; it is not a general long-context accuracy benchmark.

Useful checks:

```bash
systemctl --user status lmstudio qwen-model
lms ps
docker ps --filter name=open-webui
curl http://localhost:3000/health
```

The live setup uses Docker's `unless-stopped` restart policy and an enabled user
model service. The Nix modules declare the same setup for future rebuilds:

```bash
sudo nixos-rebuild switch --flake "path:$PWD#arch-desktop"
```

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
