{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./storage-configuration.nix
    ../../modules/base.nix
    ../../modules/desktop-i3.nix
    ../../modules/desktop-hyprland.nix
    ../../modules/nvidia-desktop.nix
    ../../modules/audio.nix
    ../../modules/desktop-power.nix
    ../../modules/gaming.nix
    ../../modules/yubikey.nix
  ];

  networking.hostName = "arch-desktop";

  # This should remain the NixOS release on which the machine was first installed.
  # Do not bump it just because nixpkgs is updated.
  system.stateVersion = "26.05";
}
