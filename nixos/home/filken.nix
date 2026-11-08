{ lib, pkgs, ... }:
let
  # Keep all Home Manager-managed dotfiles in one canonical directory.
  dotfile = rel: ./dotfiles + "/${rel}";

  fallbackWallpaper = pkgs.writeText "i3-fallback-wallpaper.ppm" ''
    P3
    1 1
    255
    8 5 43
  '';

  originalI3 = builtins.readFile (dotfile ".config/i3/config");

  originalNano = builtins.readFile (dotfile ".config/nano/nanorc");

  patchedNano = builtins.replaceStrings
    [
      "/usr/share/nano/*.nanorc"
      "/usr/share/nano-syntax-highlighting/*.nanorc"
    ]
    [
      "${pkgs.nano}/share/nano/*.nanorc"
      "${pkgs.nano-syntax-highlighting}/share/nano/*.nanorc"
    ]
    originalNano;

  patchedI3 = builtins.replaceStrings
    [
      "/usr/bin/firefox"
      "/usr/bin/thunar"
      "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
      "/usr/share/endeavouros/backgrounds/endeavouros-wallpaper.png"
      "exec --no-startup-id udiskie --no-automount --tray"
    ]
    [
      "firefox"
      "thunar"
      "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      "${fallbackWallpaper}"
      "# udiskie is managed by Home Manager"
    ]
    originalI3;

  patchedI3Scripts = pkgs.runCommand "filken-i3-scripts" {
    nativeBuildInputs = [ pkgs.bash pkgs.perl ];
  } ''
    mkdir -p "$out"
    cp -R ${dotfile ".config/i3/scripts"}/. "$out"/
    chmod -R u+w "$out"
    if grep -q '/usr/bin/powerprofilesctl' "$out/ppd-status"; then
      substituteInPlace "$out/ppd-status" \
        --replace-fail "/usr/bin/powerprofilesctl" "powerprofilesctl"
    fi
    patchShebangs "$out"
  '';
in
{
  imports = [ ./local-ai.nix ];

  home = {
    username = "filken";
    homeDirectory = "/home/filken";
    stateVersion = "26.05";

    packages = with pkgs; [
      firefox
      signal-desktop
      emacs
      mc
      pinta

      # i3 only needs GTK; skip Arc's broken GNOME Shell assets.
      (arc-theme.overrideAttrs (old: {
        mesonFlags = builtins.filter
          (flag: !(lib.hasPrefix "-Dthemes=" flag))
          (old.mesonFlags or [ ])
          ++ [ (lib.mesonOption "themes" "gtk3,gtk4") ];
      }))
      qogir-theme
      qogir-icon-theme

      rustup
      # Lean toolchain manager, including the lean and lake commands.
      elan

      bash
      coreutils
      gnugrep
      gnused
      gawk
      findutils
      procps
      iproute2
      networkmanager
      zenity
      haskellPackages.greenclip
    ];
  };

  programs.home-manager.enable = true;

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    history = {
      path = "$HOME/.histfile";
      size = 1000;
      save = 1000;
    };
    initContent = ''
      bindkey -e
    '';
  };

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile (dotfile ".config/starship.toml"));
  };

  home.file.".emacs.d/init.el".source = dotfile ".emacs.d/init.el";
  home.file.".Xresources".source = dotfile ".Xresources";
  home.file.".Xmodmap".source = dotfile ".Xmodmap";

  xdg.configFile."i3/config".text = patchedI3;
  xdg.configFile."i3/i3blocks.conf".source = dotfile ".config/i3/i3blocks.conf";
  xdg.configFile."i3/scripts" = {
    source = patchedI3Scripts;
    recursive = true;
  };

  xdg.configFile."rofi" = {
    source = dotfile ".config/rofi";
    recursive = true;
  };

  xdg.configFile."gtk-3.0" = {
    source = dotfile ".config/gtk-3.0";
    recursive = true;
  };

  xdg.configFile."xfce4/terminal" = {
    source = dotfile ".config/xfce4/terminal";
    recursive = true;
  };

  xdg.configFile."nano/nanorc".text = patchedNano;

  # The old i3 config calls ~/.screenlayout/monitor.sh. Keep its X11 path
  # connector-agnostic and seed autorandr by EDID on the first i3 login.
  home.file.".screenlayout/monitor.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -u

      xrandr_bin="${pkgs.xrandr}/bin/xrandr"
      autorandr_bin="${pkgs.autorandr}/bin/autorandr"

      detected="$($autorandr_bin --detected --match-edid 2>/dev/null || true)"
      if [[ -n "$detected" ]] && $autorandr_bin --change --match-edid; then
        exit 0
      fi

      output="$($xrandr_bin --query | ${pkgs.gawk}/bin/awk '/^[^[:space:]]+ connected/ { print $1; exit }')"
      [[ -n "$output" ]] || exit 0
      $xrandr_bin --output "$output" --auto --primary

      fingerprint="$($autorandr_bin --fingerprint 2>/dev/null || true)"
      if [[ -n "$fingerprint" ]]; then
        profile_hash="$(printf '%s' "$fingerprint" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-12)"
        profile="amd-server-$profile_hash"
        if [[ ! -d "$HOME/.config/autorandr/$profile" ]]; then
          $autorandr_bin --save "$profile" >/dev/null 2>&1 || true
        fi
      fi
    '';
  };
}
