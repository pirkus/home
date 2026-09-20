{ pkgs, ... }:
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # The existing i3 config and i3blocks volume script use amixer, including the
  # ALSA "pulse" device.  Keep those commands available on top of PipeWire.
  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-plugins
  ];
}
