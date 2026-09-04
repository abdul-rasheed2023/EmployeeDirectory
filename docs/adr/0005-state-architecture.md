# ADR 0005: Remote State Architecture

## Status
Accepted

## Context

Up to this point, Terraform state for this project lived on a local machine as `terraform.tfstate`. That works for a single person experimenting, but it breaks down quickly:

- **No team collaboration.** Local state can't be safely shared — two people applying against their own local copies will diverge and silently overwrite each other's changes.
- **No state safety.** A local `.tfstate` file is one accidental `rm`, disk failure, or laptop loss away from gone. There's no history, no recovery path.
- **No locking.** Nothing prevents two concurrent `apply` runs from corrupting state, even on a single machine with two terminals open.

The project needs a state backend that is shared, durable, versioned, and safe against concurrent writes — before any further infrastructure is built on top of it.

## Decision

Use an **S3 bucket** for remote state storage, with **S3-native locking** (`use_lockfile = true`) for concurrency control.

- **S3** holds the actual `terraform.tfstate` file, one per environment (e.g. `env/dev/terraform.tfstate`). Versioning is enabled, so any bad or corrupted state write can be rolled back to a previous version. Server-side encryption is enabled since state can contain sensitive values (e.g. connection strings, resource IDs).
- **S3-native locking** (available in Terraform 1.11+) uses a lockfile mechanism built directly into the S3 backend, removing the need for a separate DynamoDB table to coordinate locks. Terraform acquires the lock before any `plan`/`apply` that modifies state and releases it after, preventing two concurrent applies from corrupting state.

This was a deliberate change from the original plan. The **bootstrap** config (see below) originally provisioned a DynamoDB table for locking, since S3-native locking was still new at the time of planning. By the time the backend was actually wired up, S3-native locking was straightforward to use and removes an extra piece of infrastructure to maintain — so the `dev` environment's backend block uses `use_lockfile = true` instead of `dynamodb_table`. The bootstrap-created DynamoDB table (`xyz-company-tfstate-lock`) is currently unused as a result, and is being left in place rather than torn down, in case a future environment or a rollback to DynamoDB-based locking needs it.

**The S3 bucket is provisioned in a separate `bootstrap` Terraform configuration**, applied once with local state, rather than being managed by the same state it backs. This avoids a circular dependency: the resource that stores state can't itself be defined in the state it stores. The bootstrap config is expected to change rarely, if ever, after initial creation.

## Consequences

**Positive:**
- State is now durable, versioned, and recoverable.
- Concurrent applies are safely serialized instead of silently corrupting state.
- One less piece of infrastructure to manage/monitor compared to the DynamoDB approach — no separate lock table for the active locking mechanism.
- The project is ready for multi-environment and (eventually) multi-person use — new environments just get a new `key` path in the same bucket.

**Trade-offs:**
- One extra one-time manual step (`bootstrap` apply) that isn't part of the normal day-to-day workflow, and isn't covered by the same automation/CI as the rest of the infrastructure.
- The bootstrap config's own state remains local. This is an accepted, deliberate exception — bootstrapping it into S3 would recreate the same circular dependency it exists to avoid. If this becomes a team project, bootstrap state should move to a manually-secured location (e.g. a locked-down S3 bucket managed outside this repo) rather than staying local.
- The DynamoDB lock table created during bootstrap is currently unused dead infrastructure. It costs effectively nothing at this scale (`PAY_PER_REQUEST`), but should be documented as intentionally orphaned rather than forgotten, and revisited (deleted or repurposed) during a future cleanup pass.
- Losing the S3 bucket (e.g. accidental deletion) would require manual recovery via the bootstrap config and any available state backups/versioning.
