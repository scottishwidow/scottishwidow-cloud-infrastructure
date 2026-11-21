# Management

The Management environment is the `management` AWS environment. It hosts the Nextcloud instance, a `t4g.small` EC2 instance that runs Nextcloud AIO. Ansible configures it over SSM only. For the terms, see [CONTEXT.md](./CONTEXT.md).

## Terraform roots

| Root | Stack component | Owns |
| --- | --- | --- |
| `bootstrap/` | None | The state bucket `tf-state-scottishwidow-management` and its access-log bucket |
| `network/` | `aws/management/network` | The VPC, subnets, routes and internet gateway |
| `nextcloud/` | `aws/management/nextcloud` | The Nextcloud instance, its Elastic IP and security group, the backup policy and the scratch bucket |

`bootstrap` has no stack entry. Run it with plain Terraform, as in [Bootstrap a new state bucket](../../../README.md#bootstrap-a-new-state-bucket). For the state keys, see [CONTEXT.md](./CONTEXT.md#terraform-roots).

## Workflows

The workflows are in `stacks/workflows/aws-management.yaml`. They need `AWS_PROFILE`.

| Workflow | Does |
| --- | --- |
| `apply` | Applies `network` and `nextcloud`, in that order. |
| `configure` | Reads the scratch bucket from the `nextcloud` outputs, then runs `nextcloud-aio.yml`. |

There is no `destroy` and no `verify` workflow.

## Provisioning

Do the [prerequisites](../../../README.md#prerequisites) first.

1. Install the control-node prerequisites in [the Ansible README](./nextcloud/ansible/README.md#control-node-prerequisites).
2. Set `domain` in `nextcloud/secret.auto.tfvars`. Git does not keep this file.
3. Provision:

   ```sh
   atmos workflow apply -f aws-management
   ```

4. Point the `domain` A record at the Elastic IP. Route 53 is not in Terraform. Use the `UPSERT` procedure in [CONTEXT.md](./CONTEXT.md#out-of-band-route-53-a-record).
5. Configure:

   ```sh
   atmos workflow configure -f aws-management
   ```

6. Verify the mastercontainer through an SSM port-forward. See [Verify the AIO mastercontainer](./nextcloud/ansible/README.md#verify-the-aio-mastercontainer).

To plan one root, run Atmos directly:

```sh
atmos terraform plan aws/management/nextcloud -s aws-management
```

## Rules

- The only transport to the instance is SSM. There is no SSH key and no inbound port 22.
- A change to `user_data` replaces the instance. The Elastic IP stays.
- The backup policy takes nightly EBS snapshots of the instance. The snapshot is the restore path. The `pg_dumpall` escape-hatch dump is not.
- Do not initialize a root on the retired key `mgmt/terraform.tfstate`.

## Runbooks

- [Nextcloud restore from an EBS snapshot](../../../docs/runbooks/nextcloud-restore.md)
- [Nextcloud AIO smoke test](../../../docs/runbooks/nextcloud-smoke-test.md)
- [Split the management state](../../../docs/runbooks/management-state-split.md)

## Decisions

- [ADR-0001](../../../docs/adr/0001-ansible-over-ssm.md): Ansible over SSM
- [ADR-0002](../../../docs/adr/0002-self-host-nextcloud-on-t4g-small.md): Nextcloud AIO on a `t4g.small`
- [ADR-0003](../../../docs/adr/0003-ebs-snapshot-backups-via-dlm.md): EBS snapshot backups through DLM
