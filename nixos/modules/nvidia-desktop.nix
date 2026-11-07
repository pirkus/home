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

    # Deliberately do not enable laptop-only Dynamic Boost or PRIME offload.
    # NVIDIA suspend VRAM preservation is also left at its default until there
    # is a real suspend/resume reason to turn it on.
  };
}
