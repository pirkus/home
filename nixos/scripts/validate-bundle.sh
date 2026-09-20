#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

required=(
  flake.nix
  nixos/home/filken.nix
  nixos/home/dotfiles/.config/i3/config
  nixos/home/dotfiles/.config/i3/i3blocks.conf
  nixos/home/dotfiles/.config/starship.toml
  nixos/home/dotfiles/.emacs.d/init.el
  nixos/home/dotfiles/.Xresources
  nixos/home/dotfiles/.Xmodmap
  nixos/home/dotfiles/.config/hypr/hyprland.lua
  nixos/hosts/arch-desktop/configuration.nix
  nixos/hosts/arch-desktop/disko.nix
  nixos/hosts/arch-desktop/hardware-configuration.nix
  nixos/hosts/arch-desktop/storage-configuration.nix
  nixos/scripts/generate-storage-config.sh
  nixos/scripts/prepare-arch-desktop.sh
  nixos/scripts/install-arch-desktop.sh
  nixos/scripts/install-from-scratch.sh
)
for f in "${required[@]}"; do
  [[ -e "$f" ]] || { echo "missing: $f" >&2; exit 1; }
done
bash -n nixos/scripts/*.sh

grep -Fq 'FLAKE_REF="path:$REPO_ROOT"' nixos/scripts/install-arch-desktop.sh || {
  echo "install script must use an explicit path: flake reference" >&2
  exit 1
}
grep -Fq 'nixos-install --root "$TARGET_ROOT"' nixos/scripts/install-arch-desktop.sh || {
  echo "install script must pass TARGET_ROOT to nixos-install" >&2
  exit 1
}
grep -Fq -- '--disk main "$stable_id"' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must pass its selected stable disk ID to Disko" >&2
  exit 1
}
grep -Fq 'ERASE $(basename "$stable_id")' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must require destructive confirmation" >&2
  exit 1
}
for f in nixos/scripts/prepare-arch-desktop.sh nixos/scripts/generate-storage-config.sh; do
  grep -Fq '[[ "$TARGET_ROOT" == "/" ]]' "$f" || {
    echo "$f must reject the live root filesystem" >&2
    exit 1
  }
done

printf 'Static bundle validation passed.\n'
if [[ ! -e flake.lock ]]; then
  printf 'Warning: flake.lock is absent; generate it with: nix flake lock path:.\n' >&2
fi
printf 'Note: full Nix evaluation still requires: nix flake check / nix build.\n'
