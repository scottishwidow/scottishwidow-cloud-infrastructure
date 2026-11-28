# 24. The Address Registry lives outside the Corpus

Date: 2026-11-28

## Status

Accepted

## Context

A Hunt needs the AS number, the AS organisation and the country of each source
address. The Address Registry supplies them. It is a vendor dataset, so it is not
telemetry, and no Honeynet source produces it.

The Corpus has rules that do not fit a reference dataset. Every object expires after
`corpus_retention_days`. Records are verbatim source records
([ADR-0020](./0020-the-corpus-keeps-source-records-verbatim.md)). Only the Sensor
writes.

The source is DB-IP Lite (CC BY 4.0). DB-IP keeps only the current and the previous
month online. A pinned Registry Release cannot be downloaded again after about 60
days, so the repository must keep its own copy.

## Decision

The Address Registry is in its own private S3 bucket. The bucket is a second S3
module in the `corpus` root, so it outlives the Honeynet
([ADR-0022](./0022-the-corpus-outlives-the-honeynet.md)).

Each Registry Release is one Parquet file under its month prefix. An upload never
overwrites a month that exists. Current objects do not expire.

The Operator builds and uploads a Registry Release from the workstation with the
Operator profile. No CI job holds an AWS credential. The Hunt Host reads the bucket
through its instance profile, with its own DuckDB secret.

The views read one pinned Registry Release. A Hunt therefore sees the owner of an
address in that month, and not on the event date.

## Considered Options

- **A prefix in the Corpus.** Rejected. It needs an exception to the expiration rule
  and to the verbatim-record rule, and it gives a second writer to the Corpus.
- **A bucket in the `hunt` root.** Rejected. The `hunt` root is destroyed with the
  Honeynet, and a lost month cannot be downloaded again.
- **A refresh in GitHub Actions.** Rejected. It needs the first OIDC path from CI
  into AWS, for one optional run each month on public data.

## Consequences

- The `destroy-corpus` workflow also destroys the Address Registry.
- The `corpus` root holds a bucket that is not the Corpus.
- A Hunt over old months uses the owners of the pinned month. Older Registry
  Releases stay in the bucket, so a lookup by event month stays possible later.
