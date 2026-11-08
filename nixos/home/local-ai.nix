{ lib, pkgs, osConfig, ... }:
{
  # Preserve other OpenCode providers while setting the remote inference URL.
  home.activation.configureLocalAi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${../scripts/configure-local-ai.py} \
      ${lib.escapeShellArg osConfig.services.remote-ai.baseUrl}
  '';

  xdg.desktopEntries.local-chat = {
    name = "Local Chat";
    comment = "Chat through Open WebUI using the remote GPU server";
    exec = "${pkgs.xdg-utils}/bin/xdg-open http://localhost:3000";
    icon = "internet-web-browser";
    terminal = false;
    categories = [ "Network" ];
  };
}
