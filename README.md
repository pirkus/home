# AMD server

This branch contains only the `amd-server` NixOS configuration for the ASRock
B550 Phantom Gaming 4/ac, Ryzen 5 3600, 32 GiB RAM, and 4 GiB Radeon Polaris GPU.
The hostname is `nixos-amd-server`; AMD graphics use the kernel driver and Mesa.
There is no local model server, LM Studio package, NVIDIA configuration, or GPU
unlock specialisation.

Open WebUI and OpenCode start at boot without a user login and keep running
after logout. Suspend and hibernation are disabled. SSH is enabled. The local
text greeter starts i3 only after logging in as `filken`; Firefox and the usual
desktop and development tools remain available. A newly attached monitor uses
its preferred mode, with autorandr remembering saved layouts.

| Service | LAN address |
| --- | --- |
| Open WebUI | <http://nixos-amd-server.local:3000> |
| OpenCode | <http://nixos-amd-server.local:49374> |
| SSH | `ssh filken@nixos-amd-server.local` |
| WireGuard VPN | UDP `51820`; tunnel addresses `10.77.0.1` and `fd77:77:77::1` |

The WireGuard server starts at boot and routes client IPv4 and IPv6 traffic
through the home connection, including access to LAN devices. It generates a
persistent server private key outside the repository on first boot. No clients
are authorized initially. See [WIREGUARD.md](WIREGUARD.md) for router setup,
adding devices, full-tunnel client configuration, and revoking access.

Both AI clients use `http://nixos-gpu-desktop.local:1234/v1`. Change it once in
`nixos/hosts/amd-server/configuration.nix` to update both clients. The default
model remains `qwen/qwen3.8-27b`, with the existing OpenCode 128K context settings.
The GPU desktop must serve this model on its LAN interface and allow TCP 1234.
No GPU desktop settings are managed by this branch.

Open WebUI retains chats and accounts in its Docker volume. Create the first
administrator account on first use. Its configuration comes from Nix on every
start (`ENABLE_PERSISTENT_CONFIG=False`); changes made in its Admin UI do not
persist. The host's systemd-resolved stub provides `.local` resolution to the
container through host networking.

OpenCode runs as `filken` in `/home/filken`. Its service mode generates and saves
a password outside the Nix store. Log in as `filken` and retrieve it with:

```sh
opencode service get password
```

Use username `opencode` when prompted. The provider configuration is merged into
`~/.config/opencode/opencode.jsonc` without replacing other providers. As in the
previous setup, this file must contain plain JSON; existing changes are backed
up before the script updates it.

## Install

Boot the official NixOS installer in UEFI mode, connect to the network, and
copy or clone this branch onto the installer. Back up the current Arch system
and any files you want to retain first.

For a fresh installation, run as the installer user:

```sh
bash nixos/scripts/install-from-scratch.sh
```

This **erases the selected disk** after displaying its model, serial, partitions,
and requiring an explicit `ERASE …` confirmation. It installs a 1 GiB EFI
partition, 16 GiB swap, and Btrfs subvolumes for root, home, Nix, and snapshots.
Hardware is regenerated on the target computer before installation. The final
configuration is copied to `/home/filken/nixos-config` in the installed system,
and the installer prompts for the `filken` password before rebooting.

For an already partitioned installation mounted at `/mnt`, use:

```sh
bash nixos/scripts/install-amd-server.sh /mnt
```

The checked-in Disko device is deliberately a placeholder. The fresh installer
supplies the selected disk's stable `/dev/disk/by-id/…` path; do not install this
configuration directly without selecting the target disk or generating the
mounted target's hardware configuration through the preparation script.

After installation, rebuild from the saved repository:

```sh
cd /home/filken/nixos-config
sudo nixos-rebuild switch --flake path:.#amd-server
```

NetworkManager system connections are available before login. If using Wi-Fi,
create a system connection with `sudo nmcli --ask device wifi connect SSID`
before relying on headless access. Set the login password during installation;
SSH and i3 share the existing `filken` account.

Optional YubiKey enrollment:

```sh
nix shell nixpkgs#pam_u2f -c sh -c 'pamu2fcfg | sudo tee /etc/u2f_mappings'
```

## Check

```sh
bash nixos/scripts/validate-bundle.sh
nix flake check path:. --no-build
nix build path:.#nixosConfigurations.amd-server.config.system.build.toplevel
```

After boot, verify services and remote inference:

```sh
systemctl status opencode-web docker-open-webui
resolvectl query nixos-gpu-desktop.local
curl --fail http://nixos-gpu-desktop.local:1234/v1/models
sudo docker exec open-webui python -c 'import socket; print(socket.getaddrinfo("nixos-gpu-desktop.local", 1234))'
```

For upstream details see [OpenCode providers](https://opencode.ai/docs/providers),
[OpenCode service source](https://github.com/anomalyco/opencode/blob/v2.2.1/packages/cli/src/server-process.ts),
and [Open WebUI environment settings](https://docs.openwebui.com/reference/env-configuration/).
