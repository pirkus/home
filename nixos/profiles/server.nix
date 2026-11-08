{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/desktop-i3.nix
    ../modules/audio.nix
    ../modules/yubikey.nix
  ];

  # Polaris uses the kernel's amdgpu driver and Mesa for occasional i3 sessions.
  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics.enable = true;

  # A text greeter is available locally; no X server starts until i3 is chosen.
  services.displayManager.autoLogin.enable = false;
  users.users.filken.linger = true;

  # Keep services available with no monitor, no login, and after desktop logout.
  services.logind.settings.Login.IdleAction = "ignore";
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  services.openssh.enable = true;

  # Use the host resolver from containers too: ordinary container DNS cannot
  # resolve .local names through the host's Avahi NSS module.
  networking.networkmanager = {
    dns = "systemd-resolved";
    connectionConfig."connection.mdns" = 2;
  };
  services.resolved = {
    enable = true;
    settings.Resolve.MulticastDNS = true;
  };
  services.avahi = {
    enable = true;
    openFirewall = true;
    nssmdns4 = true;
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 3000 49374 ];
}
