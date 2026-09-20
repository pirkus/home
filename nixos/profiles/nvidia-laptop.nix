{ ... }:
{
  # Shared NVIDIA-laptop role. A concrete host must additionally import its
  # generated hardware configuration and a hybrid-GPU module containing the
  # correct Intel/NVIDIA or AMD/NVIDIA PRIME PCI bus IDs.
  imports = [
    ./workstation.nix
    ../modules/laptop-power.nix
  ];
}
