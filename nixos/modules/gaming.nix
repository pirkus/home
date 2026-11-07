{ pkgs, ... }:
{
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    lutris
    mangohud
    vulkan-tools
    vkd3d
  ];
}
