{ config, ... }:
{
  # Native kernel WireGuard, brought up by systemd before anyone logs in.
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.77.0.1/24" "fd77:77:77::1/64" ];
    listenPort = 51820;
    privateKeyFile = "/var/lib/wireguard/server.key";
    # Generated once on the installed server; never placed in the Nix store.
    generatePrivateKeyFile = true;
    peers = import ../hosts/amd-server/wireguard-peers.nix;
  };

  networking.firewall.allowedUDPPorts = [
    config.networking.wireguard.interfaces.wg0.listenPort
  ];

  # NAT provides return routing from the LAN without changing every LAN device.
  # IPv6 forwarding/NAT supports the clients' IPv6 default route too. NixOS
  # retains router advertisements on the server's uplink.
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    internalInterfaces = [ "wg0" ];
    # Follow the active route, so Wi-Fi/Ethernet changes need no VPN edits.
    externalInterface = null;
  };

  # If this interface is ever recreated, retry without needing a user login.
  systemd.services.wireguard-wg0.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 5;
  };
}
