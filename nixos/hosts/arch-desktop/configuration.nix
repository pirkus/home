{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./storage-configuration.nix
    ../../profiles/desktop.nix
    ../../modules/nvidia-desktop.nix
    ../../modules/local-chat.nix
  ];

  networking.hostName = "nixos-gpu-desktop";

  # Advertise nixos-gpu-desktop.local on the local network.
  services.avahi = {
    enable = true;
    openFirewall = true;
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
    };
  };

  # Allow other computers to reach LM Studio, Open WebUI, and OpenCode.
  networking.firewall.allowedTCPPorts = [ 1234 3000 49374 ];

  # Start user services, including llmster, at boot without waiting for login.
  users.users.filken.linger = true;

  boot.loader.timeout = 10;

  system.nixos.tags = [ "AMD" ];

  # Opt in from the boot menu; the normal entry keeps the stock GPU behavior.
  specialisation.gpu-unlock.configuration.imports = [ ../../modules/gpu-unlock.nix ];

  # This should remain the NixOS release on which the machine was first installed.
  # Do not bump it just because nixpkgs is updated.
  system.stateVersion = "26.05";
}
