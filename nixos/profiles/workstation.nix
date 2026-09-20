{ ... }:
{
  # Shared interactive workstation configuration. Hardware, storage, GPU and
  # laptop/desktop power policy stay in host or role-specific modules.
  imports = [
    ../modules/base.nix
    ../modules/desktop-i3.nix
    ../modules/desktop-hyprland.nix
    ../modules/audio.nix
    ../modules/gaming.nix
    ../modules/yubikey.nix
  ];
}
