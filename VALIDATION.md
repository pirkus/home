# Validation status

The bundle has been hardened against the three installation blockers identified in review:

1. **Standalone source closure:** Home Manager no longer requires an external dotfiles checkout to evaluate. Real `pirkus/home` files are preferred when present, but bundled fallbacks cover every referenced path.
2. **Hardware preparation:** the repository hardware file is a deliberate failing assertion. The fresh installer replaces it with `nixos-generate-config --no-filesystems` because Disko declares the target filesystems; `prepare-arch-desktop.sh` remains available for manually mounted layouts and verifies that `/` was detected.
3. **First login:** no plaintext or password hash is committed. `install-arch-desktop.sh` installs the system and then invokes `nixos-enter --root /mnt -c 'passwd filken'` before reboot.

Static shell validation (`bash -n`) and bundle presence checks pass. `flake.lock` was generated with Nix 2.35.2. The checked-in hardware module deliberately makes a pre-install `flake check` fail; evaluating an otherwise identical temporary copy with a minimal hardware module successfully checked the complete NixOS and Home Manager configuration.

After real hardware preparation, use these mandatory pre-install gates:

```bash
nix flake check path:.
nix build 'path:.#nixosConfigurations.arch-desktop.config.system.build.toplevel'
```
