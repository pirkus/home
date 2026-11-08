{ lib, pkgs, ... }:
let
  loadQwen = pkgs.writeShellScript "load-qwen" ''
    set -eu
    if ${pkgs.curl}/bin/curl -fsS --max-time 10 http://127.0.0.1:1234/api/v1/models |
      ${pkgs.jq}/bin/jq -e 'any(.models[] | .loaded_instances[]; .id == "qwen/qwen3.8-27b" and .config.context_length == 131072 and .config.speculative_draft_mtp == true and .config.speculative_draft_max_tokens == 5)' >/dev/null; then
      exit 0
    fi
    exec ${pkgs.lmstudio-server}/bin/lms load qwen/qwen3.8-27b --context-length 131072 --parallel 1 --gpu max --speculative-draft-mtp --speculative-draft-max-tokens 5 --identifier qwen/qwen3.8-27b --yes
  '';
in {
  # Merge with existing LM Studio prompt templates and OpenCode providers.
  home.activation.configureLocalAi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${../scripts/configure-local-ai.py}
  '';

  systemd.user.services.qwen-model = {
    Unit = {
      Description = "Keep Qwen3.8-27B loaded with 128K context and MTP";
      Requires = [ "lmstudio.service" ];
      After = [ "lmstudio.service" ];
      PartOf = [ "lmstudio.service" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${loadQwen}";
      TimeoutStartSec = 180;
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.opencode-web = {
    Unit.Description = "OpenCode shared server and web UI";
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.opencode}/bin/opencode serve --service --hostname 0.0.0.0 --port 49374";
      WorkingDirectory = "%h/home";
      Environment = "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  xdg.desktopEntries.local-chat = {
    name = "Local Chat";
    comment = "Chat with Qwen in Open WebUI";
    exec = "${pkgs.xdg-utils}/bin/xdg-open http://localhost:3000";
    icon = "internet-web-browser";
    terminal = false;
    categories = [ "Network" ];
  };
}
