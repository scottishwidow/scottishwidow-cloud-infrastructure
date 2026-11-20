# OVPN

The OVPN environment is a private Hetzner Cloud network of Private Hosts. The Gateway is the only public entry point. It is the OpenVPN server and the NAT exit of the Private Hosts. For the terms, see [CONTEXT.md](./CONTEXT.md).

## Terraform roots

| Root | Stack component | Owns |
|---|---|---|
| `bootstrap/` | None | The Hetzner state bucket and the admin SSH key |
| `network/` | `hetzner/ovpn/network` | The private network `10.10.0.0/24`, its subnet, and the default route to the Gateway |
| `openvpn/` | `hetzner/ovpn/openvpn` | The Gateway at `10.10.0.2`, its primary IPv4 and its firewall |
| `private_hosts/` | `hetzner/ovpn/private_hosts` | The Private Hosts `private-1` to `private-N`, with no public IP |

`bootstrap` keeps its state locally and has no stack entry. Every other root keeps its state in `tf-state-scottishwidow-hetzner`, under `ovpn/`.

## Workflows

The workflows are in `stacks/workflows/hetzner-ovpn.yaml`. They need `AWS_PROFILE` and `OVPN_HCLOUD_TOKEN`.

| Workflow | Does |
|---|---|
| `apply` | Applies `network`, `openvpn` and `private_hosts`, in that order. |
| `destroy` | Destroys `private_hosts`, `openvpn` and `network`, in that order. |
| `configure` | Writes `ansible/inventory/hosts.json` from the `openvpn` outputs, then runs `openvpn.yml`. |
| `verify` | Checks that `openvpn-server@server` is active on the Gateway. |

## Provisioning

Do the [prerequisites](../../../README.md#prerequisites) first, including the [Hetzner bootstrap](../../../README.md#hetzner-bootstrap).

1. Put the private key of the admin SSH key at `~/.ssh/ovpn`. Ansible uses this path.
2. Create `openvpn/terraform.tfvars` and `private_hosts/terraform.tfvars`. Git does not keep these files. The stack reads them, so they must exist.
   - In both files, set `ssh_key_name` to the SSH key name from `bootstrap`.
   - In `openvpn/terraform.tfvars`, set `admin_cidrs` to the CIDRs that can reach the Gateway on SSH.
3. Provision, configure and verify:

   ```sh
   atmos workflow apply -f hetzner-ovpn
   atmos workflow configure -f hetzner-ovpn
   atmos workflow verify -f hetzner-ovpn
   ```

4. Get the client configs from `ansible/clients/`. Git does not keep this directory.

To plan one root, run Atmos directly:

```sh
atmos terraform plan hetzner/ovpn/network -s hetzner-ovpn
```

## Teardown

The Gateway primary IPv4 has delete protection, so `destroy` stops at `openvpn` while it exists. Do these steps in this order:

1. Set `delete_protection = false` on `hcloud_primary_ip.gateway` in `openvpn/main.tf`.
2. Apply `openvpn`:

   ```sh
   atmos terraform apply hetzner/ovpn/openvpn -s hetzner-ovpn
   ```

3. Run the Teardown:

   ```sh
   atmos workflow destroy -f hetzner-ovpn
   ```

4. Set `delete_protection` back to `true` before the next `apply`.

The workflow does not destroy `bootstrap`. The Honeynet also keeps its state in the bucket that `bootstrap` creates.

## Rules

- Apply `openvpn` before `private_hosts`. The Gateway uses the fixed private IP `10.10.0.2`. If a Private Host is created first, Hetzner can give that IP to the Private Host.
- User data owns the host network of the Gateway. Ansible owns OpenVPN.
- The OpenVPN PKI exists only on the Gateway. A Gateway recreate deletes it. Run `configure` again and give each client its new config. The public IP stays, but the old configs do not work.
- To add a client, add it to `openvpn_clients` in `ansible/roles/openvpn/defaults/main.yml`, then run `configure`.

## Decisions

- [ADR-0009](../../../docs/adr/0009-gateway-public-ip-outlives-the-server.md): the Gateway public IP
- [ADR-0010](../../../docs/adr/0010-gateway-user-data-owns-the-host-network.md): user data and Ansible ownership
- [ADR-0011](../../../docs/adr/0011-vpn-clients-are-masqueraded-into-the-private-network.md): VPN client masquerade
- [ADR-0012](../../../docs/adr/0012-openvpn-pki-lives-only-on-the-gateway.md): the OpenVPN PKI
