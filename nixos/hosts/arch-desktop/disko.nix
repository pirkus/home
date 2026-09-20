{ lib, ... }:
{
  # The installer supplies the actual disk with:
  #   --disk main /dev/disk/by-id/...
  # Keeping this harmless default prevents an accidental evaluation from
  # encoding a host-specific /dev/sdX or /dev/nvmeXnY name in the repository.
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/disk/by-id/INSTALLER-MUST-CHOOSE-A-DISK";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        swap = {
          size = "16G";
          content = {
            type = "swap";
            # This size is for ordinary swap, not suspend-to-disk hibernation.
            resumeDevice = false;
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "nixos" ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd:3" "noatime" ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd:3" "noatime" ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd:3" "noatime" ];
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [ "compress=zstd:3" "noatime" ];
              };
            };
          };
        };
      };
    };
  };
}
