{ config, lib, pkgs, ... }:
let
  sessionsDir = "${config.services.displayManager.sessionData.desktops}/share";
  xsessionWrapper = config.services.displayManager.sessionData.wrapper;

  # Hyprland 0.55 ships both a raw session and a UWSM-managed session. Expose
  # only the UWSM entry in tuigreet so the login menu stays a clean i3 vs
  # Hyprland choice rather than showing two nearly-identical Hyprland entries.
  hyprlandSessions = pkgs.runCommand "tuigreet-hyprland-sessions" { } ''
    mkdir -p "$out"
    ln -s ${sessionsDir}/wayland-sessions/hyprland-uwsm.desktop \
      "$out/hyprland-uwsm.desktop"
  '';
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
          ${pkgs.xorg.xrdb}/bin/xrdb -merge "$HOME/.Xresources"
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
      # F3 opens the session menu. We expose the i3 X session and only the
      # UWSM-managed Hyprland Wayland session. Explicitly override tuigreet's X11
      # wrapper because its distro-generic default refers to /usr/bin/env,
      # which intentionally does not exist on NixOS. Keep the NixOS session
      # wrapper in the chain so profiles, Xresources and graphical-session
      # systemd targets are initialized for a selected i3 session.
      command = ''
        ${pkgs.coreutils}/bin/env \
          TUIGREET_SESSIONS_DIRS=${hyprlandSessions} \
          TUIGREET_XSESSIONS_DIRS=${sessionsDir}/xsessions \
          TUIGREET_XSESSION_WRAPPER='${pkgs.xinit}/bin/startx ${xsessionWrapper}' \
          ${lib.getExe pkgs.tuigreet} \
            --time \
            --greeting 'F3: choose i3 / Hyprland' \
            --remember \
            --remember-session \
            --remember-user-session \
            --user-menu \
            --user-menu-min-uid 1000 \
            --cmd ${pkgs.xinit}/bin/startx
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome
    dex
    feh
    xautolock
    rofi
    dunst
    xfce.xfce4-terminal
    xfce.thunar
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
    noto-fonts-emoji
    nerd-fonts.symbols-only
  ];
}
