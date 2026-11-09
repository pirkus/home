{ ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    # Required by Steam and other 32-bit games/applications.
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;

    open = true;

    nvidiaSettings = true;

    # Matches the old Arch setup that enabled nvidia-persistenced.
    nvidiaPersistenced = true;

    # Preserve graphics and CUDA allocations across suspend. The open 595+
    # driver uses kernel notifications instead of NVIDIA's systemd sleep units.
    powerManagement = {
      enable = true;
      kernelSuspendNotifier = true;
    };

    # Both GPUs can hold about 28 GiB in total; use the disk for saved VRAM.
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";

    # Deliberately do not enable laptop-only Dynamic Boost or PRIME offload.
  };
}
