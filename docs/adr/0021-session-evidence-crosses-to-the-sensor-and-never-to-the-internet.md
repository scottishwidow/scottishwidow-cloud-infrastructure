# 21. Session Evidence crosses to the Sensor and never to the internet

Date: 2026-10-23

## Status

Accepted

## Context

Cowrie and OpenCanary record what an intruder typed, tried and downloaded. That
Session Evidence must reach the Corpus. Suricata sees packets, and only the Session
Evidence shows intent.

A credential on a Honeypot would give the most hostile host in the estate a path
out of the perimeter. An SSH key for the Honeypot on the Sensor would give the same
path in the other direction.

## Decision

Vector on the Honeypot tails the Cowrie and OpenCanary logs. It sends them to a
Vector source on the Sensor. The Sensor input chain accepts that port from the
Honeynet range only. Vector on the Sensor writes to the Corpus. The Honeypot holds
no credential, and it gains no path to the internet.

Disk buffers are enabled on both hops. An outage delays delivery. It does not lose
records.

Vector is installed from apt through the allowlist proxy. `apt.vector.dev` and
`keys.datadoghq.com` are added to the allowlist as exact hosts. The Ansible role
writes the apt source list. No remote install script runs on a Honeypot.

## Consequences

- A compromised Honeypot can write false records into the Corpus. This is an
  accepted risk. The alternatives put a credential on the Honeypot, or a Honeypot
  SSH key on the Sensor.
- The Honeypot can now reach a Datadog CDN. The allowlist grows from five domains
  to seven. This is the cost of apt delivery, and it is the only new outbound
  destination for a Honeypot.
- The collector port and the time port are nftables rules. ADR-0010 keeps nftables
  in Sensor user data, so applying this replaces the Sensor. Run `make configure`
  afterwards.
- Containment does not change. The Containment assertions in the verification
  playbook must keep passing after the new ports are added.

## Amendment, 2026-11-20

Atmos workflows replace the Makefile. `make configure` is now `atmos workflow configure -f honeynet`.
