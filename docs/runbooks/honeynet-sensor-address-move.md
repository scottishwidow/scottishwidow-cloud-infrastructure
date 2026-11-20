# Runbook: Move the Sensor address to bootstrap

Move `hcloud_primary_ip.sensor` out of the `sensor` state and into the `bootstrap` state, so
that the Sensor public IPv4 survives a destroy of the disposable Honeynet roots. This runbook
is the procedure for #214. The parent issue is #209.

This runbook **writes production state**. Read the whole procedure before you start. Run it
once, before the next `apply` of the `sensor` root.

## Transfer method

`sensor` keeps its state in the Hetzner state bucket. `bootstrap` keeps its state locally.
Pull the `sensor` state to a local file, move the object between the two local copies with
`terraform state mv`, then push the `sensor` state back.

`state mv` keeps the object, its schema version and its private data unchanged, so the
address is kept and not recreated. The move is the only step that cannot be replayed from the
configuration.

## Prerequisites

- The repository at a revision that declares the address in `bootstrap` and reads it in
  `sensor` through `data.hcloud_primary_ip.sensor`.
- The environment the Honeynet stack requires:

  ```sh
  export AWS_PROFILE=personal-management
  export HONEYNET_HCLOUD_TOKEN=<honeynet project token>
  HONEYNET="$(git rev-parse --show-toplevel)/live/hetzner/honeynet"
  WORK="$(mktemp -d)"
  ```

- A backup of both states in `$WORK`. State files hold secrets. Remove `$WORK` afterwards.

## Procedure

1. Initialise both roots and back up the current states:

   ```sh
   atmos terraform init hetzner/honeynet/bootstrap -s honeynet
   atmos terraform init hetzner/honeynet/sensor -s honeynet
   terraform -chdir="$HONEYNET/sensor" state pull > "$WORK/sensor.tfstate"
   cp "$WORK/sensor.tfstate" "$WORK/sensor.tfstate.backup"
   cp "$HONEYNET/bootstrap/terraform.tfstate" "$WORK/bootstrap.tfstate.backup"
   ```

2. Note the address and the resource ID. Both are checks for later:

   ```sh
   terraform -chdir="$HONEYNET/sensor" state show hcloud_primary_ip.sensor
   ```

3. Move the object into the `bootstrap` state:

   ```sh
   terraform -chdir="$HONEYNET/bootstrap" state mv \
     -state="$WORK/sensor.tfstate" \
     -state-out="$HONEYNET/bootstrap/terraform.tfstate" \
     hcloud_primary_ip.sensor hcloud_primary_ip.sensor
   ```

4. Push the `sensor` state without the address:

   ```sh
   terraform -chdir="$HONEYNET/sensor" state push "$WORK/sensor.tfstate"
   ```

5. Plan both roots. `bootstrap` shows one in-place update, for `delete_protection` and the
   labels. `sensor` shows no change to the server and no replacement of the address. A plan
   that replaces the IP or the Sensor is a failed move: stop and restore.

   ```sh
   atmos terraform plan hetzner/honeynet/bootstrap -s honeynet
   atmos terraform plan hetzner/honeynet/sensor -s honeynet
   ```

6. Apply `bootstrap`, then confirm that the address did not change:

   ```sh
   atmos terraform apply hetzner/honeynet/bootstrap -s honeynet
   terraform -chdir="$HONEYNET/bootstrap" output sensor_public_ipv4
   ```

7. Remove the work directory:

   ```sh
   rm -rf "$WORK"
   ```

## Rollback

Before step 4, nothing is written: delete `$WORK` and restore
`bootstrap/terraform.tfstate` from the backup. After step 4, push the backup back:

```sh
cp "$WORK/bootstrap.tfstate.backup" "$HONEYNET/bootstrap/terraform.tfstate"
terraform -chdir="$HONEYNET/sensor" state push --force "$WORK/sensor.tfstate.backup"
```

## Recover the address after a loss of the bootstrap state

The `bootstrap` state is local and is not in Git. The address itself is protected in the
Hetzner project, so recovery is one import. Read the ID from the Hetzner Console or the API,
then:

```sh
atmos terraform import hetzner/honeynet/bootstrap -s honeynet hcloud_primary_ip.sensor <id>
```

The SSH key is the second object in that state and imports by name.
