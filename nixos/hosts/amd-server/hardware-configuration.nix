# Hardware observed on this machine while running Arch. The installer refreshes
# this file with nixos-generate-config; Disko owns the new installation's mounts.
{ config, lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ASRock B550 Phantom Gaming 4/ac, Ryzen 5 3600, 32 GiB RAM,
  # 500 GB GIGABYTE NVMe, Radeon RX 580-class Polaris GPU (4 GiB VRAM).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
