# 23. The bootstrap root is disposable, and the Sensor address is read at apply

Date: 2026-11-03

## Status

Accepted. Narrows [ADR-0022](./0022-the-corpus-outlives-the-honeynet.md).

## Context

ADR-0022 put the Honeynet roots in two classes and named `bootstrap` and `corpus`
durable. It reasoned that the Sensor public IPv4 is a primary IP in `bootstrap`,
so the address in the IAM trust condition survives a teardown. It therefore
carried the address to the `corpus` root in a tfvars file that is committed.

In practice the Operator destroys the Honeynet whole, including `bootstrap`. The
primary IP goes with it. A recreate gets a new address from Hetzner, and the
Operator does not choose that address. Hetzner allocates it, and the inputs are
only the type and the location.

A recorded address is therefore dead after each recreate. The trust condition
would name an address that no longer exists, and ADR-0019 gives the consequence:
shipping stops, and nothing reports an error.

The `corpus` root is already applied at each provisioning, because ADR-0019 makes
the trust anchor certificate new in each cycle.

## Decision

Only `corpus` is durable. The `bootstrap` root is disposable.

The `corpus` root reads the Sensor primary IP from Hetzner by name at each plan and
apply, with `data.hcloud_primary_ip`. The address is a result of provisioning, not
an input to it. No file records it.

The `corpus` root therefore declares the `hcloud` provider and needs
`HCLOUD_TOKEN`, which the Makefile exports for every stack.

The apply order does not change: `bootstrap`, `corpus`, `network`, `sensor`,
`honeypots`, `hunt`. The `bootstrap` root must come first, because `corpus` reads
what it creates.

## Consequences

- The `corpus` root cannot plan while no Sensor primary IP exists. Between a
  teardown and the next `bootstrap` apply, the Corpus bucket and its retention are
  unmanageable. To change the Corpus at such a time, apply `bootstrap` first.
- A durable AWS root now depends on a Hetzner project. If that project is closed
  while the Corpus still holds telemetry, the `corpus` root cannot plan until the
  data source and the address condition are removed.
- The trust policy changes in each cycle, because the address changes. The `corpus`
  root is applied in each cycle anyway, for the new trust anchor.
- ADR-0009 still holds inside one cycle: the address outlives a replacement of the
  Sensor server. It does not outlive a teardown.
- To destroy `bootstrap`, first set `delete_protection = false` on the primary IP
  and apply, as ADR-0009 states.
- The Corpus still outlives the Honeynet. The `corpus` root stays out of the
  destroy order, and a direct destroy of it still deletes the telemetry.
- The loss of the local `bootstrap` state file no longer costs the address,
  because nothing reads that state for it.

## Amendment, 2026-11-13

The address condition is in the writer role permission policy and not in the
trust policy. See the amendment to
[ADR-0019](./0019-the-sensor-holds-no-long-lived-aws-credential.md). The
consequence that the trust policy changes in each cycle now applies to the
permission policy.
