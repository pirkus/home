{ lib, pkgs, ... }:
let
  gamingScript = pkgs.runCommand "ai-gaming-mode.py" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    export PYTHONDONTWRITEBYTECODE=1
    export AI_GAMING_SOURCE=${../scripts/ai-gaming-mode.py}
    python3 ${../scripts/tests/test_ai_gaming_mode.py}
    cp ${../scripts/ai-gaming-mode.py} "$out"
  '';
  aiGamingMode = pkgs.writeShellApplication {
    name = "ai-gaming-mode";
    runtimeInputs = [ pkgs.python3 pkgs.systemd ];
    text = ''
      exec python3 ${gamingScript} "$@"
    '';
  };
in {
  programs.steam.enable = true;
  programs.gamemode = {
    enable = true;
    settings.custom = {
      start = "${aiGamingMode}/bin/ai-gaming-mode on";
      end = "${aiGamingMode}/bin/ai-gaming-mode off";
      script_timeout = 60;
    };
  };

  # Also protect CLI/daemon startup, which can bypass systemd's conditions.
  # Apply after the LM Studio overlay so every managed reference uses this gate.
  nixpkgs.overlays = lib.mkAfter [ (_final: prev: {
    lmstudio-server = prev.symlinkJoin {
      name = "lmstudio-server-gaming-guard";
      version = prev.lmstudio-server.version or "guarded";
      paths = [ prev.lmstudio-server ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/lms" \
          --run '${aiGamingMode}/bin/ai-gaming-mode check "$@" || exit 1'
        wrapProgram "$out/bin/llmster" \
          --run '${aiGamingMode}/bin/ai-gaming-mode check || exit 1'
      '';
      passthru = prev.lmstudio-server.passthru or { };
      meta = prev.lmstudio-server.meta;
    };
  }) ];

  environment.systemPackages = with pkgs; [
    aiGamingMode
    lutris
    mangohud
    vulkan-tools
    vkd3d
  ];
}
