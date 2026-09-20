{ ... }:
{
  # Share the pam-u2f settings without enabling U2F for every PAM service.
  security.pam.u2f.settings = {
    authfile = "/etc/u2f_mappings";
    cue = true;
  };

  # Password authentication remains available because U2F is sufficient rather
  # than required. Add another service explicitly if it should accept the key.
  security.pam.services.sudo.u2f = {
    enable = true;
    control = "sufficient";
  };
  security.pam.services.greetd.u2f = {
    enable = true;
    control = "sufficient";
  };

  # /etc/u2f_mappings contains hardware-specific credential material and is not
  # in the public repo. Generate it after install with:
  #   nix shell nixpkgs#pam_u2f -c sh -c 'pamu2fcfg | sudo tee /etc/u2f_mappings'
}
