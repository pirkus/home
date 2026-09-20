#!/usr/bin/env bash
set -euo pipefail

# Interactive fresh installer. Run this only from a NixOS installer booted in
# UEFI mode. It deliberately has no positional disk argument: the target is
# selected interactively and then confirmed by typing its stable by-id name.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLAKE_REF="path:$REPO_ROOT"
HOST_DIR="$REPO_ROOT/nixos/hosts/arch-desktop"
HW_FILE="$HOST_DIR/hardware-configuration.nix"

die() { echo "Error: $*" >&2; exit 1; }

require() { command -v "$1" >/dev/null || die "Required command not found: $1"; }

[[ $EUID -ne 0 ]] || die "Run this as the installer user, not as root; it uses sudo only for the destructive installation step."
[[ -d /sys/firmware/efi ]] || die "Boot the NixOS installer in UEFI mode before installing this UEFI layout."

for command in jq lsblk findmnt readlink nixos-generate-config nix; do
  require "$command"
done

cd "$REPO_ROOT"

declare -a disks=()
while IFS= read -r disk; do
  disks+=("$disk")
done < <(
  lsblk --json --output PATH,KNAME,TYPE,RM,RO,SIZE,MODEL,SERIAL,TRAN |
    jq -r '.blockdevices[] | select(.type == "disk" and .rm == false and .ro == false) | @base64'
)

((${#disks[@]} > 0)) || die "No writable, non-removable whole disks were found."

echo "The selected disk will be COMPLETELY ERASED."
echo "Only non-removable, writable whole disks are shown. USB installer media is excluded."
echo

for index in "${!disks[@]}"; do
  info="$(printf '%s' "${disks[$index]}" | base64 --decode)"
  path="$(jq -r '.path' <<<"$info")"
  size="$(jq -r '.size // "?"' <<<"$info")"
  transport="$(jq -r '.tran // "unknown"' <<<"$info")"
  model="$(jq -r '(.model // "unknown") | gsub("^[[:space:]]+|[[:space:]]+$"; "")' <<<"$info")"
  serial="$(jq -r '(.serial // "unknown") | gsub("^[[:space:]]+|[[:space:]]+$"; "")' <<<"$info")"
  printf '[%d] %s — %s, %s, model: %s, serial: %s\n' \
    "$((index + 1))" "$path" "$size" "$transport" "$model" "$serial"
  lsblk --paths --output NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$path" | sed 's/^/     /'
done

echo
read -r -p "Choose the disk number to erase (blank cancels): " choice
[[ "$choice" =~ ^[0-9]+$ ]] || die "Cancelled."
(( choice >= 1 && choice <= ${#disks[@]} )) || die "Cancelled: invalid disk number."

selected="$(printf '%s' "${disks[$((choice - 1))]}" | base64 --decode)"
disk="$(jq -r '.path' <<<"$selected")"
canonical_disk="$(readlink -f "$disk")"

# Never destroy a disk with a mounted filesystem or active swap. The user can
# boot the installer again after unmounting it, rather than this script trying
# to guess whether an unmount is safe.
if lsblk --noheadings --raw --output MOUNTPOINTS "$disk" | awk 'NF { found = 1 } END { exit !found }'; then
  die "$disk or one of its partitions is mounted. Refusing to erase it."
fi
while IFS= read -r swap_device; do
  [[ -n "$swap_device" ]] || continue
  parent="$(lsblk --noheadings --raw --output PKNAME "$swap_device" 2>/dev/null | head -n1 || true)"
  [[ "/dev/$parent" != "$canonical_disk" ]] || die "$disk contains active swap. Refusing to erase it."
done < <(swapon --noheadings --raw --output NAME 2>/dev/null || true)

# Prefer globally stable IDs. Fall back to another by-id link only when a WWN
# or NVMe EUI link is unavailable; never use an unstable /dev/sdX name here.
stable_id=""
for prefix in wwn- nvme-eui. nvme- ata- scsi-; do
  for candidate in /dev/disk/by-id/"$prefix"*; do
    [[ -L "$candidate" && "$candidate" != *-part[0-9]* ]] || continue
    [[ "$(readlink -f "$candidate")" == "$canonical_disk" ]] || continue
    stable_id="$candidate"
    break 2
  done
done
[[ -n "$stable_id" ]] || die "No stable /dev/disk/by-id identifier was found for $disk. Refusing to use an unstable device name."

echo
echo "Selected target: $stable_id -> $canonical_disk"
echo "Disk layout: GPT; 1 GiB EFI; 16 GiB swap; remaining Btrfs (@root, @home, @nix, @snapshots)."
read -r -p "Type exactly 'ERASE $(basename "$stable_id")' to continue: " confirmation
[[ "$confirmation" == "ERASE $(basename "$stable_id")" ]] || die "Confirmation did not match; nothing was changed."

echo
echo "Generating hardware configuration from the installer (without filesystem declarations) ..."
nixos-generate-config --show-hardware-config --no-filesystems > "$HW_FILE"

echo "Installing NixOS to $stable_id ..."
sudo nix run "$FLAKE_REF#disko-install" -- \
  --write-efi-boot-entries \
  --flake "$FLAKE_REF#arch-desktop" \
  --disk main "$stable_id"

echo
echo "Set the login password for filken before rebooting."
sudo nixos-enter --root /mnt -c 'passwd filken'
echo "Installation complete. Reboot only after the password command succeeds."
