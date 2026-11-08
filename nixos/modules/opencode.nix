{ lib, pkgs, ... }:
{
  # A system service running as filken starts independently of graphical login.
  # Wait for Home Manager to write the remote provider before starting OpenCode.
  systemd.services.opencode-web = {
    description = "OpenCode shared server and web UI";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [ "home-manager-filken.service" ];
    after = [ "network-online.target" "nss-lookup.target" "home-manager-filken.service" ];
    unitConfig.RequiresMountsFor = [ "/home/filken" ];
    environment = {
      HOME = "/home/filken";
      PATH = lib.mkForce "/home/filken/.nix-profile/bin:/etc/profiles/per-user/filken/bin:/run/current-system/sw/bin";
    };
    serviceConfig = {
      User = "filken";
      WorkingDirectory = "/home/filken";
      # OpenCode 2.x service mode generates and persists its own password.
      # Retrieve it as filken with: opencode service get password
      ExecStart = "${pkgs.opencode}/bin/opencode serve --service --hostname 0.0.0.0 --port 49374";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
