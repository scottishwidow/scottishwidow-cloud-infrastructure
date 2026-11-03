# 22. The Corpus outlives the Honeynet

Date: 2026-10-23

## Status

Accepted. [ADR-0023](./0023-the-bootstrap-root-is-disposable-and-the-sensor-address-is-read-at-apply.md) replaces the address mechanism, and makes the `bootstrap` root disposable.

## Context

The Honeynet is provisioned when it is needed, and destroyed afterwards. The
Corpus holds 13 months. If a teardown destroyed the Corpus, this change would have
no purpose.

A hunt reads retained telemetry. The natural time to hunt is often a time when no
Honeynet is live.

## Decision

The Honeynet roots are in two classes.

Durable, applied and never destroyed: `bootstrap` and `corpus`.

Disposable, applied and destroyed with the environment: `network`, `sensor`,
`honeypots` and `hunt`.

Apply order: `bootstrap`, `corpus`, `network`, `sensor`, `honeypots`, `hunt`.
Destroy order: `hunt`, `honeypots`, `sensor`, `network`.

The `corpus` root is in the Makefile stack list for init and apply. It is not in
the destroy order. The Sensor public IPv4 is a primary IP in `bootstrap`, so the
address in the IAM condition survives a teardown.

## Consequences

- The Corpus bucket comes from the registry S3 module. Terraform does not let a
  caller add a `lifecycle` block to a resource inside a module, so
  `prevent_destroy` cannot be set. A direct `terraform -chdir=.../corpus destroy`
  deletes 13 months of telemetry, and only the destroy order stops it. This is an
  accepted risk.
- The Corpus holds gaps for the periods when no Honeynet was live. Expiration runs
  on wall-clock time, so records expire whether or not collection runs.
- The Hunt Host is destroyed with the Honeynet. `make apply-hunt` brings it up
  alone when a hunt needs it, because the `hunt` root holds no Hetzner resource.
- The normalising views are rebuilt at each provisioning. The version-controlled
  SQL is the only source for them, and the Hunt Host stays disposable.
- The `bootstrap` root keeps local state that is not in version control. The
  generated `corpus` tfvars file is committed, so the Sensor address survives the
  loss of that state file. Recovery of the primary IP is one `terraform import`.
