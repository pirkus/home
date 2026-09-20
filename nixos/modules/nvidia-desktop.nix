{ ... }:
{
  # Desktop RTX 3080: the NVIDIA card directly drives Xorg. There is no PRIME
  # configuration and therefore no PCI bus-ID configuration to maintain.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    # Required by Steam and other 32-bit games/applications.
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;

    # RTX 3080 is Ampere, so it is supported by NVIDIA's open kernel module.
    # Userspace remains NVIDIA's proprietary driver stack.
    open = true;

    nvidiaSettings = true;

    # Matches the old Arch setup that enabled nvidia-persistenced.
    nvidiaPersistenced = true;

    # Deliberately do not enable laptop-only Dynamic Boost or PRIME offload.
    # NVIDIA suspend VRAM preservation is also left at its default until there
    # is a real suspend/resume reason to turn it on.
  };
}
