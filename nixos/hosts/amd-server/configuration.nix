{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./storage-configuration.nix
    ../../profiles/server.nix
    ../../modules/local-chat.nix
    ../../modules/opencode.nix
    ../../modules/wireguard-server.nix
  ];

  networking.hostName = "nixos-amd-server";

  # One endpoint for both clients; inference runs on the GPU desktop.
  services.remote-ai.baseUrl = "http://nixos-gpu-desktop.local:1234/v1";

  boot.loader.timeout = 10;
  system.nixos.tags = [ "AMD-server" ];
  system.stateVersion = "26.05";
}
