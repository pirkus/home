{ pkgs, ... }:
{
  # Skipped units remain inactive instead of entering a restart/failure loop.
  systemd.user.services.lmstudio = {
    Unit.ConditionPathExists = "!%t/lmstudio-gaming/active";
    Service.ExecStartPre = [ "${pkgs.coreutils}/bin/mkdir -p %h/.lmstudio/.internal/temp" ];
  };
  systemd.user.services.qwen-model.Unit.ConditionPathExists = "!%t/lmstudio-gaming/active";
}
