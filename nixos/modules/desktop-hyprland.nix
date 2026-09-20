{ pkgs, ... }:
{
  # Keep i3/X11 available, but add a first-class Wayland session alongside it.
  # UWSM gives Hyprland a clean systemd-managed session lifecycle and creates a
  # "Hyprland (uwsm-managed)" desktop entry for the login session chooser.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Hyprland's portal handles screencast/window sharing. The GTK portal covers
  # common desktop dialogs such as file pickers.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Allow hyprlock to authenticate through PAM.
  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [
    waybar
    mako
    hyprlock
    hyprshot
    grim
    slurp
    wl-clipboard
    cliphist
    swaybg
    swayidle
    wev
  ];
}
