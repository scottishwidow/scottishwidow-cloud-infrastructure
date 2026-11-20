# 17. The Sensor logs live on a volume that outlives the Sensor

Date: 2026-10-17

## Status

Accepted

## Context

A change to the honeypot ports, the DNAT or the `input` rules replaces the
Sensor (ADR-0014, ADR-0016). The replacement deletes the EVE log, the PCAP
files and the EveBox database. A threat hunt cannot look back past the last
replacement.

ADR-0013 says that the Honeynet shares nothing with other environments, and
that nothing outside it trusts it.

## Decision

- **A Hetzner Volume, the Log Volume, holds the Sensor logs.** The `sensor`
  root creates and attaches it through the `modules/hcloud_volume` module, with
  `format = "ext4"`, `automount = false` and `delete_protection = true`.
- **The volume and its attachment are separate resources from the server.**
  When Terraform replaces the Sensor, it replaces only the attachment.
- **Ansible mounts the Log Volume at `/srv/honeynet`** with systemd mount
  units. Bind mounts put `/srv/honeynet/suricata` on `/var/log/suricata` and
  `/srv/honeynet/evebox` on `/var/lib/evebox`. The paths that Suricata,
  logrotate and EveBox use do not change.
- **Suricata and EveBox have `RequiresMountsFor=`** on their log directory.
  Without the Log Volume, they do not start. They never write to the root disk
  of the Sensor.
- **On the first run, Ansible copies the logs from the root disk** to the Log
  Volume, with Suricata and EveBox stopped. It does not overwrite a file that
  is already on the Log Volume.

Object storage is not used. Suricata and EveBox still need a local disk, and a
bucket needs a credential on the Sensor. A compromised Sensor could use that
credential to delete the archive.

A log collector is not used. Inside the Honeynet, it is one more host that
still needs storage. Outside the Honeynet, it trusts data from the Honeynet and
breaks ADR-0013.

## Consequences

- Terraform can replace the Sensor and the logs stay. After the replacement,
  run `make configure` again. The Suricata and EveBox roles give the old files
  to the new service accounts.
- In IPS mode, when Suricata does not start, the `queue bypass` rule makes the
  Sensor fail open (ADR-0014). In IDS mode, Suricata sees no traffic until the
  Log Volume is back.
- Delete protection stops `make destroy` at the `sensor` root. To keep the
  Log Volume, remove it from the state with `terraform state rm` before the
  destroy, and import it again before the next apply. To delete it, first set
  `delete_protection = false` and apply.
- The Log Volume costs money while no server has it.
- The Log Volume is in the same Hetzner project and location as the Sensor. It
  is not an off-site copy. Root on the Sensor can still delete the logs.
- The Log Volume uses the location of the Sensor, so they cannot differ.
- The first run leaves the old logs on the root disk, under the bind mounts.
  They go away with the next Sensor replacement.

## Amendment, 2026-11-20

Atmos workflows replace the Makefile. `make configure` is now `atmos workflow configure -f honeynet`, and `make destroy` is now `atmos workflow destroy -f honeynet`.
