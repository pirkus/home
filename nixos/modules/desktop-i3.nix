{ config, lib, pkgs, ... }:
let
  sessionsDir = "${config.services.displayManager.sessionData.desktops}/share";
  xsessionWrapper = config.services.displayManager.sessionData.wrapper;
in
{
  services.xserver = {
    enable = true;
    xkb.layout = "us";

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        i3lock
        i3status
        i3blocks
      ];
    };

    # greetd does not start X itself. NixOS generates the i3 xsession, while
    # tuigreet wraps X sessions with startx when one is selected.
    displayManager.startx = {
      enable = true;
      generateScript = true;
      extraCommands = ''
        if [ -f "$HOME/.Xresources" ]; then
          ${pkgs.xrdb}/bin/xrdb -merge "$HOME/.Xresources"
        fi
      '';
    };
  };

  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      tappingButtonMap = "lmr";
    };
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      user = "greeter";
      # Override tuigreet's X11 wrapper: its default refers to /usr/bin/env,
      # which intentionally does not exist on NixOS. Keep the NixOS session
      # wrapper in the chain so profiles, Xresources and graphical-session
      # systemd targets are initialized for a selected i3 session. Tuigreet's
      # --remember-user-session and --remember-session modes are exclusive.
      command = lib.escapeShellArgs [
        "${pkgs.coreutils}/bin/env"
        "TUIGREET_SESSIONS_DIRS="
        "TUIGREET_XSESSIONS_DIRS=${sessionsDir}/xsessions"
        "TUIGREET_XSESSION_WRAPPER=${pkgs.xinit}/bin/startx ${xsessionWrapper}"
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--greeting"
        "Welcome — i3 desktop"
        "--remember"
        "--remember-user-session"
        "--user-menu"
        "--user-menu-min-uid"
        "1000"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome
    dex
    feh
    xautolock
    rofi
    dunst
    xfce4-terminal
    thunar
    galculator
    pavucontrol
    playerctl
    scrot
    imagemagick
    maim
    libnotify
  ];
  services.autorandr = {
    enable = true;
    matchEdid = true;
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.symbols-only
  ];
}
