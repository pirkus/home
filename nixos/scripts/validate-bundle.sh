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
  nixos/profiles/server.nix
  nixos/modules/opencode.nix
  nixos/modules/local-chat.nix
  nixos/modules/wireguard-server.nix
  nixos/hosts/amd-server/configuration.nix
  nixos/hosts/amd-server/disko.nix
  nixos/hosts/amd-server/hardware-configuration.nix
  nixos/hosts/amd-server/storage-configuration.nix
  nixos/hosts/amd-server/wireguard-peers.nix
  nixos/scripts/generate-storage-config.sh
  nixos/scripts/prepare-amd-server.sh
  nixos/scripts/install-amd-server.sh
  nixos/scripts/install-from-scratch.sh
  nixos/scripts/format-amd-server.nix
)
for f in "${required[@]}"; do
  [[ -e "$f" ]] || { echo "missing: $f" >&2; exit 1; }
done
for f in nixos/scripts/*.sh; do
  bash -n "$f"
done

grep -Fq 'FLAKE_REF="path:$REPO_ROOT"' nixos/scripts/install-amd-server.sh || {
  echo "install script must use an explicit path: flake reference" >&2
  exit 1
}
grep -Fq 'nixos-install --root "$TARGET_ROOT"' nixos/scripts/install-amd-server.sh || {
  echo "install script must pass TARGET_ROOT to nixos-install" >&2
  exit 1
}
grep -Fq -- '--argstr diskDevice "$stable_id"' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must pass its selected stable disk ID to Disko" >&2
  exit 1
}
grep -Fq -- '--extra-experimental-features "nix-command flakes"' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must enable the Nix features required by nix run" >&2
  exit 1
}
grep -Fq 'ERASE $(basename "$stable_id")' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must require destructive confirmation" >&2
  exit 1
}
grep -Fq 'bash "$REPO_ROOT/nixos/scripts/install-amd-server.sh" /mnt' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must install into the mounted target using the shared installer" >&2
  exit 1
}
if grep -Eq '^[[:space:]]*nix build|run .*#disko-install' nixos/scripts/install-{amd-server,from-scratch}.sh; then
  echo "installers must not build the full system in the live store" >&2
  exit 1
fi
grep -Fq -- '--option build-dir "$INSTALL_TMPDIR"' nixos/scripts/install-amd-server.sh || {
  echo "installer must put build scratch space on the target disk" >&2
  exit 1
}
grep -Fq '"$installed_root/home/filken/nixos-config"' nixos/scripts/install-from-scratch.sh || {
  echo "fresh installer must preserve the generated configuration" >&2
  exit 1
}
for f in nixos/scripts/prepare-amd-server.sh nixos/scripts/generate-storage-config.sh; do
  grep -Fq '[[ "$TARGET_ROOT" == "/" ]]' "$f" || {
    echo "$f must reject the live root filesystem" >&2
    exit 1
  }
done
if grep -Eq '^[[:space:]]*--remember-session[[:space:]]' nixos/modules/desktop-i3.nix \
  && grep -Eq '^[[:space:]]*--remember-user-session[[:space:]]' nixos/modules/desktop-i3.nix; then
  echo "tuigreet remember-session modes are mutually exclusive" >&2
  exit 1
fi

printf 'Static bundle validation passed.\n'
if [[ ! -e flake.lock ]]; then
  printf 'Warning: flake.lock is absent; generate it with: nix flake lock path:.\n' >&2
fi
printf 'Note: full Nix evaluation still requires: nix flake check / nix build.\n'
