{ pkgs, ... }:
{
  # The i3 configuration has a power-profile menu. On the desktop, use the
  # standard Linux power-profiles daemon rather than laptop-focused TLP.
  services.power-profiles-daemon.enable = true;

  # thermald is appropriate for an Intel CPU and does not implement laptop
  # battery policy. The motherboard/firmware remains responsible for fan curves.
  services.thermald.enable = true;

  environment.systemPackages = [
    pkgs.power-profiles-daemon
    pkgs.linuxPackages.cpupower
  ];
}
