{ lib, pkgs, config, ... }:
let
  ralph = pkgs.callPackage ../packages/ralph-orchestrator.nix { };
  # Use the actual project for task/config/loop state, not an upstream source checkout.
  # Internal subprocesses may invoke `ralph` by name. Scope this alias to the
  # service so they cannot accidentally run the unrelated @wiggumdev binary.
  serviceCli = pkgs.writeShellScriptBin "ralph" ''
    exec ${ralph}/bin/ralph-orchestrator "$@"
  '';
  # Shared OpenCode sessions survive a disconnected CLI. Give each task's
  # backend a private server so cancellation can terminate its whole process tree.
  serviceOpenCode = pkgs.writeShellScriptBin "opencode" ''
    if [[ "''${1:-}" == run ]]; then
      shift
      exec ${pkgs.opencode}/bin/opencode --standalone run --thinking "$@"
    fi
    exec ${pkgs.opencode}/bin/opencode --standalone "$@"
  '';
  workerScript = pkgs.runCommand "ralph-task-worker.py" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    export PYTHONDONTWRITEBYTECODE=1
    export RALPH_WORKER_SOURCE=${../scripts/ralph-task-worker.py}
    python3 ${../scripts/tests/test_ralph_task_worker.py}
    mkdir workspace
    cd workspace
    ${ralph}/bin/ralph-orchestrator run --autonomous --exclusive --no-auto-merge \
      --config ${workerConfig} --prompt "Check worker configuration" --dry-run > dry-run.txt
    grep -F "Backend: opencode" dry-run.txt
    cp ${../scripts/ralph-task-worker.py} "$out"
  '';
  workerConfig = pkgs.writeText "ralph-task-worker.yml" ''
    cli:
      backend: opencode
  '';
  workspace = "${config.home.homeDirectory}/dev/ralph";
  caddyfile = pkgs.writeText "ralph-orchestrator.Caddyfile" ''
    {
      admin off
      auto_https off
    }
    http://localhost:5173 {
      bind 127.0.0.1
      handle /rpc/* {
        reverse_proxy 127.0.0.1:4000
      }
      handle /health {
        reverse_proxy 127.0.0.1:4000
      }
      handle {
        root * ${ralph}/share/ralph-orchestrator/web
        try_files {path} /index.html
        file_server
      }
    }
  '';
in {
  home.packages = [ ralph ];

  systemd.user.services.ralph-orchestrator-api = {
    Unit = {
      Description = "Ralph Orchestrator workspace API";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${ralph}/bin/ralph-api";
      WorkingDirectory = workspace;
      Environment = [
        "RALPH_API_HOST=127.0.0.1"
        "RALPH_API_PORT=4000"
        "RALPH_API_TASK_LOG_DIR=${config.xdg.stateHome}/ralph-orchestrator"
        "RALPH_API_AUTH_MODE=trusted_local"
        "RALPH_API_WORKSPACE_ROOT=${workspace}"
        "RALPH_API_RALPH_COMMAND=${ralph}/bin/ralph-orchestrator"
        # Agent CLIs and Git must remain available to spawned orchestration loops.
        "PATH=${lib.makeBinPath [ serviceCli serviceOpenCode pkgs.git pkgs.bash pkgs.coreutils ]}:%h/.local/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # The 2.10.1 Rust API persists queued tasks but has no execution consumer.
  # Use its RPC interface so it remains the sole owner of task state/events.
  systemd.user.services.ralph-orchestrator-worker = {
    Unit = {
      Description = "Execute queued Ralph Orchestrator tasks";
      Wants = [ "ralph-orchestrator-api.service" ];
      After = [ "ralph-orchestrator-api.service" ];
      PartOf = [ "ralph-orchestrator-api.service" ];
    };
    Service = {
      ExecStart = lib.escapeShellArgs [
        "${pkgs.python3}/bin/python3"
        "${workerScript}"
        "--workspace" workspace
        "--state" "${config.xdg.stateHome}/ralph-orchestrator"
        "--command" "${ralph}/bin/ralph-orchestrator"
        "--default-config" "${workerConfig}"
      ];
      WorkingDirectory = workspace;
      Environment = config.systemd.user.services.ralph-orchestrator-api.Service.Environment
        ++ [ "PYTHONUNBUFFERED=1" ];
      UMask = "0077";
      # Terminate Ralph and all spawned agents when stopping/restarting the worker.
      KillMode = "control-group";
      TimeoutStopSec = 20;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.ralph-orchestrator-web = {
    Unit = {
      Description = "Ralph Orchestrator web dashboard";
      # Keep serving the UI while the API restarts during Home Manager activation.
      # Requires would stop Caddy without starting it again when the API returns.
      Wants = [ "ralph-orchestrator-api.service" ];
      After = [ "ralph-orchestrator-api.service" ];
    };
    Service = {
      ExecStart = "${pkgs.caddy}/bin/caddy run --config ${caddyfile} --adapter caddyfile";
      Environment = [ "XDG_DATA_HOME=${config.xdg.dataHome}" "XDG_CONFIG_HOME=${config.xdg.configHome}" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  xdg.desktopEntries.ralph-orchestrator = {
    name = "Ralph Orchestrator";
    comment = "Open the Ralph Orchestrator web dashboard";
    exec = "${pkgs.xdg-utils}/bin/xdg-open http://localhost:5173";
    icon = "applications-development";
    terminal = false;
    categories = [ "Development" ];
  };
}
