# Build only the partitioning/mounting tools in the live installer's store.
# The full system must be built by nixos-install in the target store instead.
{ flakeRef, diskDevice }:
let
  flake = builtins.getFlake flakeRef;
  host = flake.nixosConfigurations.amd-server.extendModules {
    modules = [
      {
        disko.devices.disk.main.device = diskDevice;
        disko.rootMountPoint = "/mnt";
      }
    ];
  };
in
assert flake.inputs.nixpkgs.lib.hasPrefix "/dev/disk/by-id/" diskDevice;
host.config.system.build.destroyFormatMount
