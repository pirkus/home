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
      "exec xrandr --output DP-4 --mode 3440x1440 -r 144.00"
      "exec --no-startup-id udiskie --no-automount --tray"
    ]
    [
      "firefox"
      "thunar"
      "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      "${fallbackWallpaper}"
      "# display mode is handled by ~/.screenlayout/monitor.sh + autorandr"
      "# udiskie is managed once by Home Manager for both i3 and Hyprland"
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

  hyprClipboard = pkgs.writeShellScriptBin "hypr-clipboard" ''
    set -eu
    selection="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -i -p Clipboard -config "$HOME/.config/rofi/rofidmenu.rasi" || true)"
    [ -n "$selection" ] || exit 0
    printf '%s\n' "$selection" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  # Hyprland equivalent of the old DP-4 xrandr line without assuming a
  # connector name. It finds the connected display that exposes 3440x1440 and
  # selects the refresh closest to 144 Hz at that resolution. If no such mode exists,
  # the wildcard `preferred` monitor rule remains in effect.
  hyprDisplaySetup = pkgs.writeShellScriptBin "hypr-display-setup" ''
    set -eu

    json="$(${pkgs.hyprland}/bin/hyprctl monitors all -j 2>/dev/null || true)"
    [ -n "$json" ] || exit 0

    choice="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r '
      [ .[] as $m
        | ($m.availableModes // [])[] as $mode
        | select($mode | test("^3440x1440@[0-9.]+Hz$"))
        | ($mode | capture("@(?<hz>[0-9.]+)Hz$").hz | tonumber) as $hz
        | { name: $m.name, mode: $mode, hz: $hz, delta: (($hz - 144) | if . < 0 then -. else . end) }
      ]
      | sort_by(.delta, (.hz * -1))
      | .[0] // empty
      | [.name, .mode]
      | @tsv
    ')"

    [ -n "$choice" ] || exit 0
    name="$(printf '%s' "$choice" | ${pkgs.coreutils}/bin/cut -f1)"
    mode="$(printf '%s' "$choice" | ${pkgs.coreutils}/bin/cut -f2)"
    [ -n "$name" ] && [ -n "$mode" ] || exit 0

    # `hyprctl eval` is the current Lua-aware runtime configuration interface.
    ${pkgs.hyprland}/bin/hyprctl eval \
      "hl.monitor({ output = \\\"$name\\\", mode = \\\"$mode\\\", position = \\\"auto\\\", scale = 1 })" \
      >/dev/null 2>&1 || true
  '';
in
{
  home = {
    username = "filken";
    homeDirectory = "/home/filken";
    stateVersion = "26.05";

    packages = with pkgs; [
      firefox
      emacs
      mc
      pinta

      arc-theme
      qogir-theme
      qogir-icon-theme

      rustup

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

      # Wayland / Hyprland user-side helpers.
      hyprClipboard
      hyprDisplaySetup
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

      target_mode="3440x1440"
      target_rate="144"
      xrandr_bin="${pkgs.xrandr}/bin/xrandr"
      autorandr_bin="${pkgs.autorandr}/bin/autorandr"

      detected="$($autorandr_bin --detected --match-edid 2>/dev/null || true)"
      if [[ -n "$detected" ]] && $autorandr_bin --change --match-edid; then
        exit 0
      fi

      output="$($xrandr_bin --query | ${pkgs.gawk}/bin/awk -v mode="$target_mode" '
        /^[^[:space:]]+ connected/    { out=$1; connected=1; next }
        /^[^[:space:]]+ disconnected/ { connected=0; next }
        connected && $1 == mode       { print out; exit }
      ')"

      if [[ -z "$output" ]]; then
        output="$($xrandr_bin --query | ${pkgs.gawk}/bin/awk '/^[^[:space:]]+ connected/ { print $1; exit }')"
      fi

      [[ -n "$output" ]] || exit 0

      if ! $xrandr_bin --output "$output" --mode "$target_mode" --rate "$target_rate" --primary; then
        if ! $xrandr_bin --output "$output" --mode "$target_mode" --primary; then
          $xrandr_bin --output "$output" --auto --primary || true
        fi
      fi

      fingerprint="$($autorandr_bin --fingerprint 2>/dev/null || true)"
      if [[ -n "$fingerprint" ]]; then
        profile_hash="$(printf '%s' "$fingerprint" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-12)"
        profile="arch-desktop-$profile_hash"
        if [[ ! -d "$HOME/.config/autorandr/$profile" ]]; then
          $autorandr_bin --save "$profile" >/dev/null 2>&1 || true
        fi
      fi
    '';
  };

  # Keep the Hyprland config as a normal repo file, parallel to the existing
  # .config/i3/config. NixOS owns the compositor/session package; Home Manager
  # just links the user-editable Lua config into ~/.config/hypr.
  xdg.configFile."hypr/hyprland.lua".source = dotfile ".config/hypr/hyprland.lua";

  # Waybar deliberately mirrors the old i3bar: bottom position, numeric
  # workspaces, dark palette, and the same basic CPU/memory/network/audio/clock
  # information. It only runs from the Hyprland start hook.
  xdg.configFile."waybar/config.jsonc".text = builtins.toJSON {
    layer = "top";
    position = "bottom";
    height = 28;
    spacing = 4;
    modules-left = [ "hyprland/workspaces" "hyprland/window" ];
    modules-right = [ "pulseaudio" "cpu" "memory" "network" "tray" "clock" ];

    "hyprland/workspaces" = {
      format = "{name}";
      on-scroll-up = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e+1\" })'";
      on-scroll-down = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e-1\" })'";
    };
    "hyprland/window" = {
      max-length = 80;
      separate-outputs = true;
    };
    pulseaudio = {
      format = "  {volume}%";
      format-muted = "󰝟 muted";
      on-click = "pavucontrol";
    };
    cpu.format = "  {usage}%";
    memory.format = "  {}%";
    network = {
      format-wifi = "  {essid}";
      format-ethernet = "󰈀  {ipaddr}";
      format-disconnected = "󰖪";
      tooltip-format = "{ifname}: {ipaddr}/{cidr}";
    };
    tray.spacing = 8;
    clock = {
      format = "{:%a %Y-%m-%d  %H:%M}";
      tooltip-format = "<tt>{calendar}</tt>";
    };
  };

  xdg.configFile."waybar/style.css".text = ''
    * {
      font-family: "Noto Sans", "Symbols Nerd Font";
      font-size: 14px;
      min-height: 0;
    }

    window#waybar {
      background: #383c4a;
      color: #ffffff;
      border: none;
    }

    #workspaces button {
      padding: 0 8px;
      color: #b0b5bd;
      background: #08052b;
      border: 0;
      border-radius: 0;
    }

    #workspaces button.active {
      color: #ffffff;
      background: #5294e2;
    }

    #workspaces button.urgent {
      color: #ffffff;
      background: #e53935;
    }

    #window,
    #pulseaudio,
    #cpu,
    #memory,
    #network,
    #tray,
    #clock {
      padding: 0 9px;
      color: #ffffff;
    }

    #clock {
      color: #e345ff;
    }
  '';

  xdg.configFile."mako/config".text = ''
    font=Noto Sans 12
    background-color=#383c4aff
    text-color=#ffffffff
    border-color=#5294e2ff
    border-size=2
    border-radius=0
    default-timeout=5000
  '';

  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
      disable_loading_bar = true
      hide_cursor = true
    }

    background {
      monitor =
      color = rgb(08052b)
    }

    input-field {
      monitor =
      size = 360, 52
      outline_thickness = 2
      outer_color = rgb(5294e2)
      inner_color = rgb(383c4a)
      font_color = rgb(ffffff)
      fade_on_empty = false
      placeholder_text = <i>Password...</i>
      position = 0, -40
      halign = center
      valign = center
    }
  '';
}
