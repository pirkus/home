# Arch -> NixOS mapping for `arch-desktop`

| Existing repo behavior | NixOS representation |
|---|---|
| `pacman -S ...` package block | NixOS/Home Manager package lists + program modules |
| `greetd` + `tuigreet --cmd i3` | `services.greetd` + tuigreet F3 session chooser for i3/X11 or Hyprland/UWSM |
| NVIDIA packages | `services.xserver.videoDrivers = [ "nvidia" ]` + `hardware.nvidia` |
| `lib32-nvidia-utils` / gaming libs | `hardware.graphics.enable32Bit = true` |
| `nvidia-persistenced` | `hardware.nvidia.nvidiaPersistenced = true` |
| `nvidia-prime` from old generic package list | **not used** on this desktop target |
| TLP/AC battery snippets | **not used** on this desktop target |
| i3 power-profile menu | standard `power-profiles-daemon` |
| Steam/GameMode/MangoHud/Vulkan | NixOS modules + packages |
| pam-u2f edits | `security.pam.u2f` + PAM service options |
| `/etc/systemd/system.conf` timeout | `systemd.settings.Manager.DefaultTimeoutStopSec` |
| raw dotfiles checkout into `$HOME` | Home Manager owns links/configuration |
| Arch-specific `/usr/...` i3 paths | patched to PATH or Nix store paths |
| `xrandr --output DP-4 --mode 3440x1440 -r 144` | hard-coded connector removed; runtime helper discovers the output, applies 3440x1440@144, then autorandr tracks the monitor by EDID |

| i3-only desktop | i3 remains available; `programs.hyprland` adds a parallel Wayland/UWSM session |
| i3bar/i3blocks | Waybar in Hyprland; existing i3bar/i3blocks remain untouched in i3 |
| dunst | Mako in Hyprland; dunst remains the i3 notifier |
| i3lock/xautolock | Hyprlock + swayidle in Hyprland |
| greenclip | cliphist + wl-clipboard in Hyprland; greenclip remains for i3 |
| `scrot`/`maim` | Hyprshot in Hyprland |

## Hardware generation

`nixos/scripts/prepare-arch-desktop.sh /mnt` generates the normal
`hardware-configuration.nix` from the installed target. No hand-entered GPU PCI
IDs are needed for the normal single-GPU desktop configuration.

## Storage discovery

Additional IDE/SATA/NVMe data filesystems are generated into
`nixos/hosts/arch-desktop/storage-configuration.nix` by
`nixos/scripts/generate-storage-config.sh`. They use stable filesystem UUIDs,
`nofail`, systemd lazy automounting, and `x-gvfs-show`. System/recovery/boot
partitions and container filesystems are excluded. Removable devices use
UDisks2 + Home Manager `udiskie`.
