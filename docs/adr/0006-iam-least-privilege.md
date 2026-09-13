# ADR 0006: IAM Least Privilege for EKS — Cluster Role, Node Role, and IRSA

**Status:** Accepted
**Date:** 2026-09-13

## Context

The EKS cluster requires three distinct IAM trust boundaries, each with a different blast
radius if over-scoped:

1. **Cluster role** — assumed by the EKS control plane itself, to manage the cluster's
   AWS-side resources (ENIs, load balancer integration, etc.).
2. **Node role** — assumed by every EC2 instance in the managed node group. Anything
   granted here is available to *every pod on every node*, regardless of which
   application that pod is running, unless further restricted.
3. **Pod-level identity (IRSA)** — IAM Roles for Service Accounts, via OIDC federation
   between the cluster's own OIDC provider and IAM, allowing an individual Kubernetes
   ServiceAccount to assume a specific, narrowly-scoped IAM role.

## Decision

Use IRSA for all application-level AWS access (S3 photo storage, DynamoDB metadata,
Parameter Store for Data Protection keys — see ADR 0007), rather than granting these
permissions to the node role.

**Why this matters, concretely:** if the employee-directory app's S3/DynamoDB/Parameter
Store permissions were attached to the node IAM role instead, *any other pod scheduled
onto the same node* — including future workloads with no legitimate reason to touch
employee photo data — would inherit that access implicitly, simply by co-locating on the
same EC2 instance. IRSA scopes the credential to the specific pod's ServiceAccount via a
trust-policy condition on `sub: system:serviceaccount:<namespace>:<service-account-name>`,
so only that ServiceAccount's pods can assume the role — no other workload on the same
node gets it for free.

## Implementation

- A dedicated Terraform module (`modules/app-irsa`) provisions the trust policy
  (`sts:AssumeRoleWithWebIdentityCredentials`, scoped via `StringEquals` conditions on both
  `aud` and `sub`) and the permissions policy, kept separate from the cluster/node roles.
- The permissions policy is scoped per-resource, not per-service-wildcard — e.g.
  `s3:GetObject`/`PutObject`/`DeleteObject` scoped to `${bucket_arn}/*`, not `s3:*` on all
  buckets; SSM actions scoped to a specific parameter path prefix, not all of Parameter
  Store (see ADR 0007).
- The pod's Kubernetes ServiceAccount is annotated with
  `eks.amazonaws.com/role-arn: <app_irsa role ARN>`, which the AWS SDK's default credential
  chain automatically detects and uses inside the pod — no explicit credential
  configuration needed in application code.

## What Went Wrong in Practice (and why it's worth documenting)

Two real incidents surfaced during hands-on IRSA work, both worth carrying into the
interview story bank as genuine "IRSA isn't just theory" evidence:

1. **Stale kubeconfig after cluster recreation.** `kubectl` failed with a DNS resolution
   error against the cluster's API endpoint — the locally cached kubeconfig held a stale
   endpoint hostname from a previous cluster instance. Fixed via
   `aws eks update-kubeconfig --name <cluster> --region <region>`, which regenerates the
   config from the cluster's *current* live state rather than trusting a locally cached
   copy. **Lesson:** IRSA and cluster identity are tied to the specific cluster instance,
   not the cluster name — a cluster recreation invalidates cached client config even though
   the name is unchanged.

2. **EKS Access Entry policy scope mismatch.** A user with `AmazonEKSAdminPolicy`
   attached to their EKS access entry received `Forbidden` errors on
   `pods/ephemeralcontainers` — despite the policy name sounding equivalent to full
   cluster-admin. `AmazonEKSAdminPolicy` is designed for **namespace-scoped** access;
   `AmazonEKSClusterAdminPolicy` is the actual cluster-wide equivalent of Kubernetes'
   built-in `cluster-admin` ClusterRole. **Lesson:** AWS's EKS access-policy naming is not
   self-evidently ordered by privilege level — verify the intended access *scope*
   (`cluster` vs `namespace`) against the actual policy, not just its name.

## Alternatives Considered

- **Node-role-only permissions** (rejected): simpler to set up, but violates least
  privilege at the pod level — any pod on the node inherits app-level AWS access it has no
  legitimate need for.
- **Static IAM user credentials mounted as Kubernetes Secrets** (rejected): requires manual
  credential rotation, risks credential sprawl across repos/configs, and provides no
  cryptographic binding to the specific workload identity the way IRSA's OIDC federation
  does.

## Consequences

- Every new AWS-facing capability the app needs requires an explicit, reviewed IAM policy
  statement addition to `app_irsa` — slightly more Terraform ceremony per feature, in
  exchange for an auditable, per-capability permission trail.
- IRSA setup requires the cluster's OIDC provider to exist first — a real ordering
  dependency worth calling out in any "what would you do differently" interview follow-up
  (the OIDC provider and IRSA role should be provisioned before, or in the same apply as,
  any workload that depends on it).
