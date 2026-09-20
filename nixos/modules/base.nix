{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The Arch README used this as an NVMe stability workaround.  Deliberately
  # not carrying over "nomodeset" because that would fight the NVIDIA setup.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.fstrim.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  security.polkit.enable = true;

  programs.zsh.enable = true;

  # Keep users mutable so a password set during installation with passwd persists.
  users.mutableUsers = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.filken = {
    # Keep the conventional first-user UID stable so ownership on existing
    # Linux data disks carries over from the Arch installation.
    uid = 1000;
    isNormalUser = true;
    description = "Filip";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
  };

  environment.systemPackages = with pkgs; [
    codex
    git
    curl
    wget
    jq
    openssh
    unzip
    nano
    less
    perl
    python3
    ripgrep
    fd

    # X11 tools present in the Arch setup.
    xauth
    xrdb
    xmodmap
    xrandr
    xset
    xclip

    # Network helper. Removable storage is handled by Home Manager udiskie.
    wireguard-tools

    # Diagnostics / hardware tools.
    acpi
    sysstat
    brightnessctl
    upower
    powertop
    lm_sensors
    pciutils
    usbutils
  ];
}
