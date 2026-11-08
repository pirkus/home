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

# A mounted RAM filesystem would still put the target store in RAM.
for target_path in "$TARGET_ROOT" "$TARGET_ROOT/nix"; do
  [[ -e "$target_path" ]] || continue
  target_fstype="$(findmnt --noheadings --output FSTYPE --target "$target_path")"
  case "$target_fstype" in
    tmpfs|ramfs)
      echo "Target storage is RAM-backed: $target_path. Mount the installation disk first." >&2
      exit 1
      ;;
  esac
done

./nixos/scripts/prepare-amd-server.sh "$TARGET_ROOT"

# nixos-install builds directly in TARGET_ROOT/nix. Keep evaluation caches and
# build scratch space on that disk as well, including when sudo drops TMPDIR.
INSTALL_TMPDIR="$(sudo mktemp -d "$TARGET_ROOT/nixos-install.XXXXXXXX")"
cleanup() { sudo rm -rf -- "$INSTALL_TMPDIR"; }
trap cleanup EXIT
sudo chmod 0755 "$INSTALL_TMPDIR"

echo
echo "Building and installing NixOS using the target disk..."
sudo env TMPDIR="$INSTALL_TMPDIR" XDG_CACHE_HOME="$INSTALL_TMPDIR/cache" \
  nixos-install --root "$TARGET_ROOT" --flake "$FLAKE_REF#amd-server" \
  --no-channel-copy --no-root-password --option build-dir "$INSTALL_TMPDIR"

echo
echo "Set the login password for filken before rebooting."
echo "NixOS users declared without a password cannot log in with password authentication."
sudo nixos-enter --root "$TARGET_ROOT" -c 'passwd filken'

echo
echo "Install complete. Do not reboot until passwd filken succeeded."
echo "See README.md for headless services and post-install checks."
