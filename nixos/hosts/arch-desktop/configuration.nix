{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./storage-configuration.nix
    ../../profiles/desktop.nix
    ../../modules/nvidia-desktop.nix
  ];

  networking.hostName = "arch-desktop";

  # This should remain the NixOS release on which the machine was first installed.
  # Do not bump it just because nixpkgs is updated.
  system.stateVersion = "26.05";
}
