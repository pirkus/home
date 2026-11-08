# WireGuard setup

`wg0` starts at boot on UDP **51820**, with IPv4/IPv6 forwarding and NAT through
the active uplink. Server addresses: `10.77.0.1` and `fd77:77:77::1`.

## 1. Server and router

Install this branch's NixOS configuration. The server key is generated once at
`/var/lib/wireguard/server.key`; back it up and keep it out of Git.

```sh
sudo systemctl status wireguard-wg0
sudo wg show wg0 public-key
```

Reserve the server's LAN address in DHCP and forward **UDP 51820** to it.
Use your public IP or DDNS hostname as the client endpoint.

## 2. Generate and authorize a client

Let the WireGuard app generate its keypair, or run this on the Linux client
with `wg` installed, in a private directory outside the repository:

```sh
umask 077
wg genkey | tee phone.key | wg pubkey > phone.pub
cat phone.pub
```

Add the public key inside the list in
`nixos/hosts/amd-server/wireguard-peers.nix`:

```nix
{
  name = "phone";
  publicKey = "CLIENT_PUBLIC_KEY";
  allowedIPs = [ "10.77.0.2/32" "fd77:77:77::2/128" ];
}
```

Apply on the server:

```sh
cd /home/filken/nixos-config
sudo nixos-rebuild switch --flake path:.#amd-server
```

## 3. Configure the client

Import this into the WireGuard app, replacing the three placeholders. The
client private key is the content of `phone.key` or the app-generated key.

```ini
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.77.0.2/32, fd77:77:77::2/128
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = PUBLIC_IP_OR_DDNS:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Both default routes send internet traffic through home, including DNS. LAN
access works by IP; `.local` multicast discovery doesn't cross the tunnel.
Tunneled IPv6 internet access needs a working server IPv6 uplink.

## 4. Test and manage

Connect from outside the LAN. Check `sudo wg show wg0` for a handshake, confirm
that the client's public IP uses the home connection, and test a `192.168.1.x`
LAN device. Open WebUI is at `http://10.77.0.1:3000`.

For each additional device, use new keys, filenames, and unique addresses
(`.3` / `::3`, etc.); don't overwrite existing keys. To revoke access, remove
its peer entry and rebuild. For startup errors:

```sh
journalctl -u wireguard-wg0 -u wireguard-wg0-key -b
```
