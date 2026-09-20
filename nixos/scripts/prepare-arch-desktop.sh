#!/usr/bin/env bash
set -euo pipefail

# Run from anywhere inside the repository. The first argument is the mounted
# NixOS target root, normally /mnt from the installer.
TARGET_ROOT="${1:-/mnt}"
TARGET_ROOT="${TARGET_ROOT%/}"
[[ -n "$TARGET_ROOT" ]] || TARGET_ROOT="/"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST_DIR="$REPO_ROOT/nixos/hosts/arch-desktop"
HW_FILE="$HOST_DIR/hardware-configuration.nix"

command -v nixos-generate-config >/dev/null || {
  echo "nixos-generate-config is required (run this from the NixOS installer)." >&2
  exit 1
}

if [[ "$TARGET_ROOT" == "/" ]]; then
  echo "Refusing to prepare the live root filesystem (/)." >&2
  echo "Mount the target NixOS root separately, normally at /mnt." >&2
  exit 1
fi

if [ ! -d "$TARGET_ROOT" ]; then
  echo "Target root does not exist: $TARGET_ROOT" >&2
  exit 1
fi

if ! mountpoint -q "$TARGET_ROOT"; then
  echo "Target root is not a mount point: $TARGET_ROOT" >&2
  exit 1
fi

echo "Generating hardware configuration from $TARGET_ROOT ..."
sudo nixos-generate-config --root "$TARGET_ROOT"
cp "$TARGET_ROOT/etc/nixos/hardware-configuration.nix" "$HW_FILE"

if ! grep -Eq 'fileSystems\."/"|fileSystems = .*"/"' "$HW_FILE"; then
  echo "Generated hardware configuration does not define the target root filesystem (/)." >&2
  echo "Make sure the NixOS target root is actually mounted at $TARGET_ROOT, then run this script again." >&2
  exit 1
fi

echo "Generated $HW_FILE"

echo
echo "Scanning attached internal IDE/SATA/NVMe data filesystems ..."
"$REPO_ROOT/nixos/scripts/generate-storage-config.sh" "$TARGET_ROOT"

# This host does not need PRIME bus IDs: the RTX 3080 is the primary desktop
# GPU. Still show the detected display devices as a sanity check when lspci is
# available.
if command -v lspci >/dev/null; then
  echo
  echo "Detected display-class PCI devices:"
  lspci -Dnn | grep -Ei 'VGA|3D|Display' || true
fi
