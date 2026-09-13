# Runbook: Manual Steps Terraform Didn't Handle (EKS Recreate + Create-Form Bug)

**Context:** This runbook captures real manual interventions required during hands-on EKS
work — both the Day 38 destroy/recreate exercise and the antiforgery/Data Protection bug
investigation. Per the mentor plan's Day 38 note: "document any manual step you had to do
that Terraform didn't handle... that's a gap worth closing before Month 4's RDS work."

---

## Issue 1: Stale kubeconfig after cluster recreation

**Symptom:**
```
dial tcp: lookup <old-endpoint-id>.gr7.us-east-1.eks.amazonaws.com: no such host
```
`kubectl` commands failed entirely with a DNS resolution error, even though the cluster
was confirmed live via `aws eks describe-cluster`.

**Root cause:** the locally cached kubeconfig held a cluster API endpoint from a *previous*
instance of the cluster (EKS clusters get a new random endpoint hostname when recreated,
even under the same cluster name). `kubectl` had no way to know the cluster had been
replaced underneath it.

**Manual fix (not automated by Terraform):**
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```
This regenerates the kubeconfig from the cluster's live, current state.

**Gap to close:** consider scripting this as a standard post-`apply` step in the team's
deploy tooling/README, rather than relying on each engineer remembering to re-run it after
any cluster-affecting apply.

---

## Issue 2: EKS Access Entry with wrong policy scope

**Symptom:**
```
Error from server (Forbidden): pods "..." is forbidden: User "..." cannot patch
resource "pods/ephemeralcontainers"
```
This occurred despite the user having `AmazonEKSAdminPolicy` attached via an EKS Access
Entry — which sounds like full admin access but isn't.

**Root cause:** `AmazonEKSAdminPolicy` is scoped for **namespace-level** access;
`AmazonEKSClusterAdminPolicy` is the actual cluster-wide equivalent of Kubernetes'
`cluster-admin` ClusterRole. The naming similarity is misleading.

**Manual fix:**
```bash
aws eks disassociate-access-policy --cluster-name <cluster> --principal-arn <arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy

aws eks associate-access-policy --cluster-name <cluster> --principal-arn <arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

**Gap to close:** if Access Entries are managed via Terraform in a future iteration,
explicitly document which policy ARN maps to which real-world access level in the ADR/code
comment — don't rely on policy names being self-explanatory.

---

## Issue 3: `terraform destroy` fails on Kubernetes/Helm provider auth

**Symptom:**
```
Error: Kubernetes cluster unreachable: invalid configuration: no configuration has been
provided, try setting KUBERNETES_MASTER environment variable
```
This occurred during `terraform destroy`, even though the same `kubernetes`/`helm`
provider blocks worked fine during `apply`, and the underlying `aws eks get-token` command
succeeded when run manually outside Terraform.

**Root cause:** the `kubernetes`/`helm` provider blocks are configured dynamically via
`exec { command = "aws", args = ["eks", "get-token", ...] }`, with the cluster
endpoint/CA sourced from `module.eks` outputs. This is a known category of Terraform
limitation: provider configuration computed from resource/module attributes can fail to
resolve reliably specifically during a full `destroy`, due to how Terraform orders
provider initialization versus resource destruction in that mode. This is not a
credentials or region misconfiguration — it reproduces even with valid, working AWS
credentials.

**Manual fix (workaround, not automated):**
1. Delete Kubernetes/Helm-managed resources directly via `kubectl`/`helm`, while the
   cluster is still fully reachable (before touching Terraform's destroy at all):
   ```bash
   kubectl delete ingress <ingress-name>
   kubectl delete svc <service-name>
   helm uninstall <helm-release-name>
   kubectl delete deployment <deployment-name>
   kubectl delete serviceaccount <service-account-name>
   kubectl delete hpa <hpa-name>
   ```
2. **Verify the ALB is actually gone** before proceeding — an Ingress-managed ALB created
   outside direct Terraform tracking will not be cleaned up by `terraform destroy` if the
   Kubernetes provider never successfully processes the delete, and an orphaned ALB can
   also block VPC/security-group deletion later:
   ```bash
   aws elbv2 describe-load-balancers --region <region> --query "LoadBalancers[*].LoadBalancerName" --output table
   ```
3. Remove the now-manually-deleted resources from Terraform state, since they no longer
   exist for Terraform to manage:
   ```bash
   terraform state rm kubernetes_ingress_v1.<name>
   terraform state rm kubernetes_service_v1.<name>
   terraform state rm helm_release.<name>
   terraform state rm kubernetes_deployment_v1.<name>
   terraform state rm kubernetes_service_account_v1.<name>
   terraform state rm kubernetes_horizontal_pod_autoscaler_v2.<name>
   ```
4. Run `terraform destroy` for the remaining infrastructure (EKS, VPC, RDS, IAM, S3,
   DynamoDB, etc.), which no longer depends on the Kubernetes/Helm providers.

**Gap to close:** this is a strong "reproducibility isn't automatic" finding for the
Day 38 exercise itself — the infrastructure is not a single clean `terraform destroy` away
from a full teardown as currently structured. Worth an explicit note in the destroy runbook
and a follow-up decision: either accept this two-phase destroy process as the documented
standard procedure, or investigate `terraform destroy -target` sequencing / a `depends_on`
restructure that forces provider config resolution before the Kubernetes-level resources
are targeted for destruction.

---

## Day 38 Evidence Log (actual run, 2026-09-13)

**What actually happened, in order:**
1. First `terraform destroy` attempt failed immediately with the Kubernetes provider
   auth error above, before destroying anything.
2. Manually deleted the Ingress, Service, Helm release, Deployment, ServiceAccount, and
   HPA via `kubectl`/`helm` directly; confirmed the ALB was gone via
   `aws elbv2 describe-load-balancers`.
3. Removed those 6 resources from Terraform state via `terraform state rm`.
4. **Re-ran `terraform destroy` — it again failed partway through**, this time after
   successfully destroying RDS, S3, DynamoDB, ECR, Secrets/notifications, and the
   `app_irsa` module, but leaving the EKS cluster, node group, OIDC provider,
   `lb_controller_irsa`, and the entire VPC/NAT/subnet/route-table layer stuck in state
   while the actual EKS cluster and node group no longer existed in AWS (`aws eks
   describe-cluster` returned `ResourceNotFoundException` while `terraform state list`
   still showed them). This is a second, distinct instance of the same underlying
   Kubernetes/Helm provider limitation — it can abort a destroy run partway through, not
   just refuse to start.
5. Diagnosed the drift by cross-checking `terraform state list` against live AWS
   (`aws eks describe-cluster`, `aws eks list-clusters`, `aws iam get-role` for the EKS
   IAM roles, `aws iam list-open-id-connect-providers`) to determine exactly which
   resources were state-only versus genuinely still live and cost-incurring (the VPC and
   NAT Gateway were confirmed still live and billing — this was the actual risk of not
   catching the partial destroy).
6. Removed `module.eks.aws_eks_cluster.this`, `module.eks.aws_eks_node_group.this`, and
   `helm_release.aws_lb_controller` from state (all three either already gone from AWS or
   unreachable via the broken Kubernetes provider).
7. Re-ran `terraform destroy` a third time — this run's plan showed **28 resources, all
   plain AWS resources with no Kubernetes/Helm provider dependency** — and it completed
   cleanly with zero errors.

**Timing (destroy phase 3, the successful completion):** 00:05:00 (5 minutes), with the
NAT Gateway teardown alone accounting for 42 seconds of that — consistent with AWS's
typical NAT Gateway deletion time.

**Post-destroy verification (all confirmed clean):**
```
terraform state list                 → empty
aws eks list-clusters                → []
aws ec2 describe-nat-gateways        → []
aws rds describe-db-instances        → []
```

**Interview-relevant framing:** the honest version of this story is not "I ran
`terraform destroy` and it worked" — it's "I ran it, it silently left cost-incurring
infrastructure (VPC, NAT Gateway) orphaned in state-vs-reality drift, I caught that by
cross-referencing state against live AWS rather than trusting the CLI output alone, and I
resolved it with a targeted, verified state reconciliation before safely completing the
teardown." That is a materially stronger operational-maturity story than a clean run would
have produced.

---

## Summary Table

| Issue | Category | Automatable? |
|---|---|---|
| Stale kubeconfig post-recreate | Client-side cache, not infra | Yes — script `update-kubeconfig` into standard post-apply steps |
| Wrong EKS Access Entry policy scope | Human/naming error | Partially — document policy ARN meanings; consider Terraform-managing access entries |
| `terraform destroy` provider auth failure | Terraform tooling limitation | No — requires the two-phase manual workaround above; this is a known ecosystem limitation, not a bug in this codebase |
