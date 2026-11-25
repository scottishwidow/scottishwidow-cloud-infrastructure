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

## Amendment, 2026-11-20

Atmos workflows replace the Makefile. The `honeynet` workflows hold the apply and destroy order, only `destroy-corpus` destroys `corpus`, and `make apply-hunt` is now `atmos workflow apply-hunt -f honeynet`.

## Amendment, 2026-11-25

The Corpus keeps 13 months. The Operator decides when the Honeynet runs. A live period of a few days is one possible pattern, not a fixed duty cycle. Thus the collection time in a month changes from month to month, and a count that is compared across periods measures uptime as well as attacker behaviour.

A Hunt that compares counts across periods divides by collection time. The `corpus_coverage` view gives one row for each `source`, `host` and `dt`, with the first event time, the last event time and the record count.

These options are rejected:

- Run the Honeynet continuously. This adds the monthly Hetzner cost of the Sensor, `honeypot-1`, the Log Volume and the primary IPv4, and removes the Operator's control of the duty cycle.
- Shorten `corpus_retention_days` to the duty cycle. This removes the year-on-year comparison, and the Corpus storage cost is small.

Cost: the S3 storage of 13 months of Corpus objects. No Hetzner cost is added.
