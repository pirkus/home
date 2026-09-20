#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${1:-/mnt}"
TARGET_ROOT="${TARGET_ROOT%/}"
[[ -n "$TARGET_ROOT" ]] || TARGET_ROOT="/"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLAKE_REF="path:$REPO_ROOT"
cd "$REPO_ROOT"

if [[ "$TARGET_ROOT" == "/" ]]; then
  echo "Refusing to install through the live root filesystem (/)." >&2
  echo "Mount the target NixOS root separately, normally at /mnt." >&2
  exit 1
fi

if ! mountpoint -q "$TARGET_ROOT"; then
  echo "Target root is not a mount point: $TARGET_ROOT" >&2
  echo "Partition and mount the NixOS root filesystem first." >&2
  exit 1
fi

./nixos/scripts/prepare-arch-desktop.sh "$TARGET_ROOT"

echo
echo "Building NixOS configuration..."
nix build "$FLAKE_REF#nixosConfigurations.arch-desktop.config.system.build.toplevel"

echo
echo "Installing NixOS..."
sudo nixos-install --root "$TARGET_ROOT" --flake "$FLAKE_REF#arch-desktop"

echo
echo "Set the login password for filken before rebooting."
echo "NixOS users declared without a password cannot log in with password authentication."
sudo nixos-enter --root "$TARGET_ROOT" -c 'passwd filken'

echo
echo "Install complete. Do not reboot until passwd filken succeeded."
echo "After first boot, enroll the YubiKey separately as documented in README-NIXOS.md."
