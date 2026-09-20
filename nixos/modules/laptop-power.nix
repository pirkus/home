{ config, pkgs, ... }:
{
  # Use the standard desktop power-profile API consumed by the shared i3
  # status block and menu. Host-specific CPU tuning can be added separately.
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = [
    pkgs.power-profiles-daemon
    config.boot.kernelPackages.cpupower
  ];
}
