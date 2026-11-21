# Context Map

## Contexts

- [Management](./live/aws/management/CONTEXT.md) — the `management` AWS environment:
  the Nextcloud instance, its Terraform, and the Ansible that configures it.
- [OVPN](./live/hetzner/ovpn/CONTEXT.md) — the `ovpn` Hetzner Cloud environment:
  the Gateway and the Private Hosts behind it.
- [Honeynet](./live/hetzner/honeynet/CONTEXT.md) — the `honeynet` environment: Honeypots
  that attract attacks for Suricata to inspect, and the Corpus and Hunt Host that hunt the
  telemetry they produce. The environment spans two directories: `live/hetzner/honeynet/`
  holds the Hetzner roots and the `CONTEXT.md`, and `live/aws/honeynet/` holds the AWS roots.
  `live/aws/honeynet/` is a logical environment inside the shared AWS account. There is no
  `honeynet` AWS account. See [ADR-0018](./docs/adr/0018-the-corpus-is-an-s3-bucket-in-the-shared-aws-account.md).
- **IaC security triage — archived.** The pipeline that scanned the Terraform for
  misconfigurations, assigned each finding a verdict with a rationale, and proposed
  a patch where a human asked for one. It was a proof of concept, it worked, and its
  code, workflows and design are held at the tag `poc/iac-security-triage` rather
  than on `main`. Trivy still scans and still raises alerts; nothing triages them.
  To bring it back, see [the restore runbook](./docs/runbooks/iac-security-triage-restore.md).

## Relationships

- **Honeynet → nothing inbound**: the Honeynet shares no network, Hetzner project,
  Hetzner token or SSH key with any other context. Nothing in another context may route to
  it or trust it.
- **Honeynet → Corpus (write only)**: the Sensor ships Suricata telemetry and Honeypot
  Session Evidence to the Corpus, an S3 bucket in the shared AWS account. The Sensor can
  write and cannot read or delete, and it holds no long-lived credential — IAM Roles
  Anywhere issues short-lived ones, conditioned on the Sensor address. This replaces the
  earlier reading that the Honeynet shares nothing but state.
  See [ADR-0019](./docs/adr/0019-the-sensor-holds-no-long-lived-aws-credential.md).
- **Hunt Host → Corpus (read only)**: the Hunt Host reads the Corpus through its instance
  profile. No reader credential exists. It has its own VPC and shares no network with
  Nextcloud, because it parses content an attacker controls.
- **Honeynet → OVPN (state only)**: the Honeynet keeps its state files under
  their own keys in the Hetzner state bucket, which the OVPN bootstrap creates.
  The OVPN bootstrap must exist first. The state bucket and the Corpus are the only
  shared resources, and both live in the one AWS account.

- **Terraform → Ansible**: Terraform (`live/aws/management/nextcloud/`) provisions
  the instance and supporting resources (EIP, backup policy, SSM scratch bucket);
  Ansible (`live/aws/management/nextcloud/ansible/`) configures Nextcloud AIO on it,
  standalone (no `remote-exec`). They share no state file — Ansible discovers the
  instance via dynamic inventory (tags) and reads bucket/region from Terraform outputs.
- **DNS**: Route 53 is outside Terraform. The operator updates the A record manually
  with the `UPSERT` procedure in `live/aws/management/CONTEXT.md`.
- **Scan → Management (reads only)**: Trivy reads every `.tf` file in the repo,
  but it provisions nothing and holds no AWS credentials — it reads *code*, never
  live infrastructure. Its findings reach code scanning as alerts and stop there
  while triage is archived.
- **ADRs, design docs → nothing**: they are *not* agent input. This is the line
  ADR-0008 draws. `main` has no agent and no `docs/design/` while triage is
  archived. If triage is restored, its corpus assembler is the one place the line
  could be quietly crossed — it may contain code and never prose.

## Shared language

These terms apply to every context.

**Durable root**:
A root that outlives a Teardown of its environment. No destroy workflow contains it.
*Avoid*: Persistent root, permanent root, protected root

**Teardown**:
The destruction of every root of one environment that is not a Durable root.
*Avoid*: Decommission, cleanup
