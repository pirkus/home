{ lib, pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.consoleMode = "max";
  # Without a limit every generation stays in the boot menu forever.
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Enable NTFS mounting (including Thunar/UDisks removable-drive mounts).
  boot.supportedFilesystems = [ "ntfs" ];

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

  programs.java = {
    enable = true;
    package = pkgs.temurin-bin-21;
  };

  virtualisation.docker.enable = true;

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
      "docker"
      "video"
      "audio"
      "input"
    ];
  };

  environment.systemPackages = with pkgs; [
    codex
    claude-code
    opencode
    qwen-code
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

    # JVM development tools; use Temurin 21 for Maven's default runtime too.
    kotlin
    (maven.override { jdk_headless = temurin-bin-21; })

    # IntelliJ IDEA, current unified build (2026.x). nixpkgs classifies it
    # unfree (JetBrains-licensed): Community features are included, paid
    # features need a JetBrains subscription.
    intellij-idea

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

    # Stable LM Studio, provided by the lmstudio-nix overlay.
    lmstudio
    # Prefer the headless CLI over the desktop package's duplicate lms binary.
    (lib.hiPrio lmstudio-server)
  ];
}
