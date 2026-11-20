# scottishwidow-infrastructure

## Environments

Each environment has one Atmos stack. The stack documentation tells how to provision, configure, verify and destroy the environment.

| Environment | Path | Stack | Documentation |
|---|---|---|---|
| Management | `live/aws/management` | `aws-management` | [Management](./live/aws/management/README.md) |
| OVPN | `live/hetzner/ovpn` | `hetzner-ovpn` | [OVPN](./live/hetzner/ovpn/README.md) |
| Honeynet | `live/hetzner/honeynet`, `live/aws/honeynet` | `honeynet` | [Honeynet](./live/hetzner/honeynet/README.md) |

For the terms and the relations between the environments, see [CONTEXT-MAP.md](./CONTEXT-MAP.md).

## Prerequisites

### Tools

- Terraform 1.10 or later. The S3 backends use `use_lockfile`, which needs 1.10.
- Atmos 1.232.0 exactly. `atmos.yaml` stops on another version. The workflows run every environment in the correct order.
- Ansible, to configure the hosts.
- OpenSSL 3, for the Sensor CA of the Honeynet.

### AWS credentials

The Terraform roots keep their state in S3 buckets in `eu-central-1`:

| Roots | State bucket |
|---|---|
| `live/aws/management/bootstrap` | `tf-state-scottishwidow-management`, key `mgmt/bootstrap/terraform.tfstate` |
| `live/aws/management/network` | `tf-state-scottishwidow-management`, key `mgmt/network/terraform.tfstate` |
| `live/aws/management/nextcloud` | `tf-state-scottishwidow-management`, key `mgmt/nextcloud/terraform.tfstate` |
| `live/hetzner/ovpn/*` | `tf-state-scottishwidow-hetzner`, keys under `ovpn/` |
| `live/hetzner/honeynet/*`, `live/aws/honeynet/*` | `tf-state-scottishwidow-hetzner`, keys under `honeynet/` |

The credentials must be able to read, write and delete objects in the bucket, including the `.tflock` lock file.

```sh
export AWS_PROFILE=<profile>
```

### Hetzner Cloud tokens

Each Hetzner environment has its own Hetzner Cloud project and API token with Read & Write permission:

```sh
export OVPN_HCLOUD_TOKEN=<token>
export HONEYNET_HCLOUD_TOKEN=<token>
```

Each stack gives its own token to Terraform as `HCLOUD_TOKEN`, in the `env:` section of the stack file. Atmos ignores an `HCLOUD_TOKEN` that the shell already exports. The two tokens never cross, because the two Hetzner projects share nothing.

### Bootstrap a new state bucket

A bootstrap root can create its state bucket and keep its own state in that bucket. When the bucket does not exist yet, Terraform cannot initialize the S3 backend. Do these steps in this sequence:

1. In the bootstrap root, set the bucket and key in the `backend "s3"` block.
2. Create `backend_override.tf` in the bootstrap root. Git ignores this file.

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

3. Create the bucket with local state:

   ```sh
   terraform init
   terraform apply
   ```

4. Delete `backend_override.tf`. Then move the local state to the bucket:

   ```sh
   terraform init -migrate-state
   ```

Do not do these steps when the bucket exists. Use `terraform init` and `terraform apply` as usual.

### Hetzner bootstrap

`live/hetzner/ovpn/bootstrap` creates the Hetzner state bucket, which both Hetzner environments share, and the OVPN admin SSH key. It keeps its state locally. Set `ssh_key_name` and `ssh_public_key_path` in `live/hetzner/ovpn/bootstrap/terraform.tfvars`. Git does not keep this file. Apply the root manually before all other Hetzner roots:

```sh
cd live/hetzner/ovpn/bootstrap
HCLOUD_TOKEN=$OVPN_HCLOUD_TOKEN terraform apply
```

## Atmos

Atmos orchestrates each root through a stack, in `atmos.yaml` and `stacks/`. Atmos workflows in `stacks/workflows/` own the apply and destroy order of each environment. Each workflow file has the name of its stack and sets that stack:

```sh
atmos workflow <workflow> -f <stack>
```

The documentation of each stack lists its workflows. Obey these rules for all stacks:

- Each workflow stops before Terraform runs if `AWS_PROFILE` or the Hetzner token of the environment is not set.
- `apply` and `destroy` ask for confirmation at each root.
- `apply` ends after the last Terraform root. Run `configure` and `verify` separately.
- There is no `plan` workflow. A root reads earlier roots with data sources, so its plan does not show changes that are not yet applied to those roots. Plan one root at a time:

  ```sh
  atmos terraform plan <component> -s <stack>
  ```

- No workflow turns off delete protection. Turn off the protection and apply that root before a `destroy` workflow. A protected resource stops the destroy at its root.
- Stack files are the only source of Terraform variable values. Only secrets come from `TF_VAR_*` or the environment.

The state bucket `bootstrap` roots, `live/aws/management/bootstrap` and `live/hetzner/ovpn/bootstrap`, have no stack entry. They create the backend of the other roots. Run them with plain Terraform, as in [Bootstrap a new state bucket](#bootstrap-a-new-state-bucket).

## Documentation

- [Architecture decision records](./docs/adr/)
- [Runbooks](./docs/runbooks/)
