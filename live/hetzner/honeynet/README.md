# Honeynet

The Honeynet attracts real attacks so that Suricata can inspect hostile traffic. It is hostile by design. It shares no network, Hetzner project, token or SSH key with other environments. For the terms, see [CONTEXT.md](./CONTEXT.md).

## Architecture

```mermaid
flowchart LR
    attacker(["Internet<br/>attackers"])
    operator(["Operator<br/>workstation"])

    subgraph hcloud["Hetzner Cloud project: honeynet"]
        fw["Hetzner firewall<br/>tcp 21, 22, 23, 80, 445, 1433, 3306 from any<br/>tcp 2222 from admin_cidrs"]

        subgraph net["Network honeynet 10.20.0.0/24<br/>route 0.0.0.0/0 via 10.20.0.2"]
            hgw["Hetzner network gateway<br/>10.20.0.1"]

            subgraph sensor["Sensor (cx23)<br/>public IPv4 + 10.20.0.2"]
                direction TB
                sshd_s["sshd :2222<br/>key only"]
                subgraph nft["nftables (user data)"]
                    dnat["prerouting DNAT<br/>public ports to honeypot-1<br/>Honeypot 80/443/53 out to Sinkhole"]
                    fwd["forward chain<br/>1. Containment drop<br/>2. queue 0 bypass<br/>3. established accept"]
                    inp["input chain<br/>queue 0 bypass for Sinkhole flows<br/>proxy, collector, NTP and Sinkhole ports<br/>from Honeynet only"]
                end
                suricata["Suricata<br/>IDS: af-packet / IPS: NFQUEUE 0<br/>ET Open + local rules"]
                evebox["EveBox<br/>127.0.0.1:5636"]
                logvol[("Log Volume<br/>/srv/honeynet")]
                squid["Squid allowlist proxy<br/>10.20.0.2:3128"]
                vector_s["Vector<br/>collector :6000<br/>disk buffers"]
                signer["aws_signing_helper<br/>Sensor certificate"]
                chrony["chrony<br/>NTP udp 123"]
                subgraph sink["Sinkhole (rootless Podman)"]
                    nginx["nginx<br/>:10080 HTTP, :10443 HTTPS<br/>200 + empty shell script"]
                    coredns["CoreDNS<br/>:10053<br/>A = 1.1.1.1, AAAA empty"]
                end
            end

            subgraph hp["honeypot-1 (cx23)<br/>10.20.0.11, no public IP"]
                direction TB
                cowrie["Cowrie<br/>SSH :2222, Telnet :2223"]
                canary["OpenCanary<br/>FTP :2121, HTTP :8080<br/>MSSQL :1433, MySQL :3306"]
                dark["tcp 445<br/>Dark Port, dropped"]
                sshd_h["sshd :22<br/>from 10.20.0.2 only"]
                dockerd["Docker daemon<br/>DNS 8.8.8.8, proxy :3128"]
                vector_h["Vector<br/>disk buffer"]
                timesyncd["timesyncd<br/>Sensor only"]
            end
        end
    end

    subgraph aws["AWS"]
        rolesanywhere["IAM Roles Anywhere<br/>trust anchor = Sensor CA<br/>writer role"]
        corpus[("Corpus bucket<br/>source= / host= / dt=<br/>13 months")]
        hunt["Hunt Host (t4g.medium)<br/>DuckDB, hunt command<br/>no inbound ports"]
    end

    upstream["Allowlisted mirrors<br/>Ubuntu, Hetzner, Docker"]

    attacker -->|"tcp 21, 22, 23, 80,<br/>445, 1433, 3306"| fw
    operator -->|"SSH :2222"| fw
    fw --> dnat
    dnat --> fwd
    fwd -->|"22→2222, 23→2223"| cowrie
    fwd -->|"21→2121, 80→8080,<br/>1433, 3306"| canary
    fwd -->|"445"| dark
    fwd -. "NFQUEUE 0 / af-packet" .-> suricata
    inp -. "NFQUEUE 0 / af-packet" .-> suricata
    suricata -->|"eve.json"| evebox
    suricata -->|"EVE, PCAP"| logvol
    evebox -->|"database"| logvol
    fw --> sshd_s
    sshd_s -. "ProxyCommand SSH :22" .-> sshd_h

    hp -->|"default route"| hgw
    hgw -->|"network route"| sensor
    cowrie -->|"wget http/https,<br/>DNS lookups"| dnat
    dnat --> inp
    inp --> nginx
    inp --> coredns
    dockerd -->|"apt, image pulls"| squid
    squid --> upstream
    fwd -->|"any other new<br/>outbound: DROP"| blocked(["Dropped<br/>Containment"])

    cowrie -->|"cowrie.json"| vector_h
    canary -->|"opencanary.log"| vector_h
    vector_h -->|"Session Evidence<br/>tcp 6000"| inp
    inp --> vector_s
    timesyncd -->|"udp 123"| inp
    inp --> chrony
    logvol -->|"eve.json"| vector_s
    vector_s -. "credential process" .-> signer
    signer -->|"HTTPS 443"| rolesanywhere
    vector_s -->|"HTTPS 443<br/>gzip NDJSON"| corpus
    hunt -->|"HTTPS 443<br/>read only"| corpus
    operator -->|"SSM session"| hunt
```

## Hosts

| Host | Address | Runs |
|---|---|---|
| Sensor | Public IPv4, `10.20.0.2` | nftables, Suricata, EveBox, Squid, Sinkhole (nginx, CoreDNS), Vector, `aws_signing_helper`, chrony |
| `honeypot-1` | `10.20.0.11`, no public IP | Cowrie and OpenCanary in Docker, Vector, timesyncd |
| Hunt Host | AWS VPC public subnet, no inbound ports | DuckDB, the `hunt` command |

The Log Volume is attached to the Sensor at `/srv/honeynet`. It holds `/var/log/suricata` and `/var/lib/evebox`, and it stays when Terraform replaces the Sensor.

Every packet between the internet and a Honeypot goes through the Sensor. The Honeypot default route goes to the Hetzner network gateway. The network route sends it to the Sensor.

## Traffic

| Flow | Path | Result |
|---|---|---|
| Attack on a honeypot port | Sensor DNAT, then forward chain | Cowrie or OpenCanary answers. Port 445 times out. |
| New Honeypot connection to the internet | Forward chain, rule 1 | Dropped (Containment). |
| Honeypot HTTP, HTTPS or DNS to the internet | Sensor DNAT to the Sinkhole | The Sinkhole answers. Nothing leaves the Honeynet. |
| Honeypot apt and image pulls | Squid on `10.20.0.2:3128` | Allowlisted domains only. |
| Operator SSH | Sensor `:2222`, then ProxyCommand to Honeypot `:22` | Key only, from `admin_cidrs`. |
| Session Evidence | Honeypot Vector to Sensor Vector on `10.20.0.2:6000` | The Sensor forwards records from known sources and hosts only. |
| Telemetry to the Corpus | Sensor Vector to S3 over HTTPS, with Roles Anywhere credentials | Gzip objects under `source=/host=/dt=`, kept 13 months. |
| Honeypot time | timesyncd to chrony on Sensor `udp 123` | The Honeypot ignores time servers from DHCP. |
| Hunt | Operator SSM session to the Hunt Host. DuckDB reads the Corpus over HTTPS. | Read only. The Hunt Host accepts no inbound connections. |

Suricata sees all forwarded and Sinkhole flows. In IPS mode, `bypass` makes the Sensor fail open when Suricata does not read the queue. Containment does not depend on Suricata.

## Ports

| Public port | Honeypot port | Service |
|---|---|---|
| 22 | 2222 | Cowrie SSH |
| 23 | 2223 | Cowrie Telnet |
| 21 | 2121 | OpenCanary FTP |
| 80 | 8080 | OpenCanary HTTP |
| 1433 | 1433 | OpenCanary MSSQL |
| 3306 | 3306 | OpenCanary MySQL |
| 445 | 445 | Dark Port, no service |

## Terraform roots

| Root | Stack component | Owns |
|---|---|---|
| `bootstrap/` | `hetzner/honeynet/bootstrap` | The Hetzner SSH key and the Sensor public IPv4. It keeps its state locally. |
| `live/aws/honeynet/corpus/` | `aws/honeynet/corpus` | The Corpus bucket, the Sensor writer role and the Roles Anywhere trust anchor |
| `network/` | `hetzner/honeynet/network` | The network `10.20.0.0/24` and its route to the Sensor |
| `sensor/` | `hetzner/honeynet/sensor` | The Sensor, its firewall and the Log Volume |
| `honeypots/` | `hetzner/honeynet/honeypots` | `honeypot-1` |
| `live/aws/honeynet/hunt/` | `aws/honeynet/hunt` | The Hunt Host, its VPC and its scratch bucket |

## Workflows

The workflows are in `stacks/workflows/honeynet.yaml`. All workflows need `AWS_PROFILE`. All workflows except `apply-hunt`, `configure-hunt` and `verify-hunt` also need `HONEYNET_HCLOUD_TOKEN`.

| Workflow | Does |
|---|---|
| `apply` | Applies `bootstrap`, generates the Sensor CA, then applies `corpus`, `network`, `sensor`, `honeypots` and `hunt`, in that order. |
| `destroy` | Destroys `hunt`, `honeypots`, `sensor`, `network` and `bootstrap`, in that order, then deletes `pki/`. It never destroys `corpus`. |
| `configure` | Writes the inventory from the Terraform outputs, then runs `site.yml`. |
| `verify` | Runs `verify.yml` against the Sensor and the Honeypots. |
| `apply-hunt` | Applies `hunt` alone. |
| `configure-hunt` | Installs DuckDB on the Hunt Host and creates the normalising views. |
| `verify-hunt` | Runs the Hunt `verify.yml`. Run `verify` first. |
| `destroy-corpus` | Destroys `corpus` alone. See [Full teardown](#full-teardown). |

## Provisioning

Do the [prerequisites](../../../README.md#prerequisites) first. The Honeynet keeps its state in the bucket that `live/hetzner/ovpn/bootstrap` creates.

1. Create a key pair for the Honeynet only, at `~/.ssh/honeynet`. Do not use a key that is trusted elsewhere.
2. Set `admin_cidrs` in `sensor/terraform.tfvars`. This file is not in Git.
3. Provision and configure:

   ```sh
   atmos workflow apply -f honeynet      # bootstrap, Sensor CA, corpus, network, sensor, honeypots, hunt
   atmos workflow configure -f honeynet  # writes the inventory, runs site.yml, issues the Sensor certificate
   atmos workflow verify -f honeynet     # runs verify.yml
   ```

   `bootstrap` creates the Hetzner SSH key and the Sensor public IPv4, and keeps its state locally. The `corpus` root reads this address by name, so `bootstrap` comes before `corpus`.

4. Configure and verify the Hunt Host:

   ```sh
   atmos workflow configure-hunt -f honeynet  # installs DuckDB and creates the normalising views
   atmos workflow verify-hunt -f honeynet     # runs the Hunt verify.yml
   ```

   Run `verify` before `verify-hunt`. `verify-hunt` reads the Session Evidence probe that `verify` sends, and it finds only a probe from the last 7 days.

The order is fixed:

1. The `apply` workflow generates the Sensor CA in `pki/` on the workstation after `bootstrap` and before `corpus`, if `pki/ca.crt` does not exist. The CA private key does not leave the workstation.
2. The `corpus` apply registers the CA certificate as the Roles Anywhere trust anchor.
3. The `configure` workflow generates the Sensor private key on the Sensor and issues a new Sensor certificate from the CA. Each run issues a new certificate. Nothing on the Sensor renews it.

To plan one root, run Atmos directly. The `corpus` root reads `pki/ca.crt` and the Sensor primary IP at plan, so `pki/` and `bootstrap` must exist:

```sh
atmos terraform plan aws/honeynet/corpus -s honeynet
```

### Teardown

The `destroy` workflow removes `hunt`, `honeypots`, `sensor`, `network` and `bootstrap` in that order, then deletes `pki/`. It never destroys `corpus`, so the Corpus keeps 13 months of telemetry. The next `apply` generates a new CA, and Hetzner gives the Sensor a new address. `corpus` puts that address in the writer role permission policy. See [ADR-0022](../../../docs/adr/0022-the-corpus-outlives-the-honeynet.md) and [ADR-0023](../../../docs/adr/0023-the-bootstrap-root-is-disposable-and-the-sensor-address-is-read-at-apply.md).

The workflow does not turn off delete protection. Do these steps by hand first:

1. Decide what to do with the Log Volume. To keep it, remove it from the `sensor` state. To delete it, set `delete_protection = false` and apply. See [Rules](#rules).
2. Set `delete_protection = false` on `hcloud_primary_ip.sensor` in `bootstrap/main.tf`, then apply `bootstrap`:

   ```sh
   atmos terraform apply hetzner/honeynet/bootstrap -s honeynet
   ```

3. Run the Teardown:

   ```sh
   atmos workflow destroy -f honeynet
   ```

4. Set `delete_protection` back to `true` before the next `apply`.

### Full teardown

A full teardown deletes the Corpus and all retained telemetry. This is not the normal procedure. [ADR-0022](../../../docs/adr/0022-the-corpus-outlives-the-honeynet.md) keeps `corpus` across a Teardown.

`destroy-corpus` is the only workflow that destroys `corpus`. The `corpus` root reads `pki/ca.crt` and the Sensor primary IP, so run it while `pki/` and `bootstrap` still exist. Run each step in this order:

1. Empty the Corpus bucket by hand, including all object versions and delete markers. The bucket is versioned. `destroy-corpus` does not empty it, and it stops with an error while the bucket holds objects.
2. `atmos workflow destroy-corpus -f honeynet`
3. Do the [Teardown](#teardown). This also deletes the Hetzner SSH key.

To move an address that an older revision created in the `sensor` root, follow [the address move runbook](../../../docs/runbooks/honeynet-sensor-address-move.md).

## Operation

- **EveBox.** Open an SSH local forward, then go to `http://localhost:5636`:

  ```sh
  ssh -i ~/.ssh/honeynet -p 2222 -L 5636:127.0.0.1:5636 admin@<sensor_public_ipv4>
  ```

- **IDS or IPS.** Set `suricata_mode` in `ansible/playbooks/group_vars/all.yml`, then run `atmos workflow configure -f honeynet`. nftables does not change.
- **Rule updates.** A systemd timer runs `suricata-update` daily for ET Open.
- **Hunt.** The Hunt Host is disposable. To start a hunt on its own, run `atmos workflow apply-hunt -f honeynet`, then `atmos workflow configure-hunt -f honeynet`. To stop it, run `atmos terraform destroy aws/honeynet/hunt -s honeynet`. The Corpus does not change.

## Rules

- User data owns sysctl and nftables on all hosts. Ansible only checks them.
- A change to the honeypot ports, the DNAT or the nftables rules replaces the Sensor. Run `atmos workflow configure -f honeynet` again after the replacement.
- To add a honeypot port, add it to `honeypot_tcp_ports` in the Sensor root. If the port is below 1024, also map it in `honeypot_port_redirects` in `stacks/_honeynet-defaults.yaml`.
- Do not open Containment. Send new outbound protocols to the Sinkhole.
- The Honeynet collects no malware samples.
- To revoke the Sensor credential, set `sensor_writer_profile_enabled = false` in the `corpus` root and run `atmos terraform apply aws/honeynet/corpus -s honeynet`. There is no CRL.
- The Log Volume has delete protection. To destroy the Sensor and keep the logs, run `atmos terraform state rm hetzner/honeynet/sensor -s honeynet module.sensor_log_volume.hcloud_volume.this` before the `destroy` workflow. Before the next `apply`, import it again with `atmos terraform import hetzner/honeynet/sensor -s honeynet module.sensor_log_volume.hcloud_volume.this <volume_id>`.
- To delete the Log Volume, set `delete_protection = false` on the `sensor_log_volume` module, apply `sensor`, then run the `destroy` workflow.
- Every banner and identity comes from `honeypot_persona` in `ansible/playbooks/group_vars/all.yml`. Do not set a banner in a role.

## Decisions

- [ADR-0013](../../../docs/adr/0013-suricata-runs-on-an-inline-sensor-that-enforces-containment.md): inline Sensor and Containment
- [ADR-0014](../../../docs/adr/0014-a-static-queue-bypass-rule-keeps-the-sensor-network-in-user-data.md): static `queue bypass` rule
- [ADR-0015](../../../docs/adr/0015-opencanary-replaces-dionaea-and-port-445-becomes-a-dark-port.md): OpenCanary and the Dark Port
- [ADR-0016](../../../docs/adr/0016-the-sinkhole-runs-in-rootless-podman-on-the-sensor.md): the Sinkhole
- [ADR-0017](../../../docs/adr/0017-the-sensor-logs-live-on-a-volume-that-outlives-the-sensor.md): the Log Volume
- [ADR-0017](../../../docs/adr/0017-every-honeypot-service-claims-one-ubuntu-persona.md): the Persona
- [ADR-0019](../../../docs/adr/0019-the-sensor-holds-no-long-lived-aws-credential.md): the Sensor credential
