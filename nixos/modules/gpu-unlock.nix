{ config, lib, pkgs, ... }:
let
  gpuUnlock = config.boot.kernelPackages.callPackage ../packages/gpu-unlock.nix { };
in
{
  # This module is imported only by the optional boot specialisation.
  system.nixos.tags = lib.mkAfter [ "GPU-unlock-3080" ];
  boot.kernelParams = [ "gpu_unlock.targets=0000:03:00.0" ];
  boot.extraModulePackages = [ gpuUnlock ];
  hardware.firmware = [ gpuUnlock.firmware ];
  boot.initrd.availableKernelModules = [ "gpu_unlock" ];

  # Run before both explicit module loading and udev coldplug can bind NVIDIA.
  # A softdep would conflict with the NVIDIA module's existing softdep rule.
  boot.initrd.systemd.services.gpu-unlock = {
    description = "Unlock RTX 3080 tensor throughput before NVIDIA loads";
    wantedBy = [ "sysinit.target" ];
    before = [
      "systemd-modules-load.service"
      "systemd-udevd.service"
      "systemd-udev-trigger.service"
    ];
    after = [ "systemd-tmpfiles-setup-dev-early.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.kmod}/bin/modprobe gpu_unlock";
      TimeoutStartSec = 30;
    };
  };
}
