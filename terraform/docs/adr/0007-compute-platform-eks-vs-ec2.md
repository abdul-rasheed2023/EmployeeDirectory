# ADR 0007: Compute Platform Selection (EKS vs EC2+ASG)

## Status
Accepted — implemented.

## Context
The original infrastructure plan for the Employee Directory app called for a
conventional EC2 + Auto Scaling Group compute tier behind an Application
Load Balancer (`modules/compute` + a load-balancer module), matching the
structured Month 3 build plan as originally scoped.

Partway through the build, the goal set shifted from "ship the app" to
"ship the app on a platform that demonstrates production Kubernetes and
Terraform module-authoring skill" — directly targeting the Kubernetes and
IaC gaps identified against Gulf Engineering Manager job descriptions
(container orchestration, GitOps, IRSA-based pod identity). Continuing with
EC2+ASG would have completed the app but added little toward that
portfolio and certification goal (CKA in particular).

## Decision
Move the application compute tier from EC2+ASG to Amazon EKS.

Concretely:
- `modules/eks` provisions the control plane, a managed node group, and the
  cluster's OIDC identity provider (foundation for IRSA).
- `modules/lb-controller-irsa` grants the AWS Load Balancer Controller
  pod-level IAM permissions via IRSA, so it can provision ALBs/NLBs
  on behalf of Kubernetes Ingress/Service objects — replacing the
  Terraform-managed ALB the EC2 design would have used.
- `modules/network` tags public/private subnets with
  `kubernetes.io/cluster/<name>` and `kubernetes.io/role/elb` /
  `internal-elb` so the Load Balancer Controller can auto-discover them.
- `modules/ecr` and `modules/ci-oidc` were added to support building and
  pushing container images from GitHub Actions via OIDC (no static AWS
  keys), which an EC2/AMI-based deploy path would not have needed in the
  same form.
- `modules/compute` was **not removed** — it still provisions the EC2
  launch template/instance for a bastion host, since a jump box for
  ad-hoc VPC access (e.g. reaching RDS directly) is still useful. It no
  longer runs application workloads; the retired ASG/launch-template
  application-tier resources are left out of state rather than kept as
  dead code.

## Consequences

**Positive**
- Produces a directly relevant EKS + Terraform + IRSA portfolio piece and
  covers the Kubernetes-in-production gap flagged in the Gulf EM job
  description analysis.
- IRSA gives pod-level IAM scoping (Load Balancer Controller, and any
  future workload roles) instead of a broader node-level instance profile
  — a stronger least-privilege story for interviews.
- OIDC-federated GitHub Actions (`modules/ci-oidc`) removes the need for
  long-lived AWS access keys in CI, which an EC2/AMI pipeline would
  likely have used.

**Negative / trade-offs**
- Materially more infrastructure to run and reason about than EC2+ASG:
  control plane, node group, OIDC provider, and (outside Terraform) the
  Load Balancer Controller Helm install itself.
- EKS control plane cost applies from cluster creation regardless of
  workload size, versus EC2 instances that can be stopped between demos.
- The AWS Load Balancer Controller is not yet installed via Terraform —
  `lb-controller-irsa` only provisions the IAM role; the Helm install
  (`kubectl`/`helm`, using the `lb_controller_role_arn` output as the
  service account's `eks.amazonaws.com/role-arn` annotation) is a manual
  follow-up step, not currently codified in this repo.
- Two now-unused resource paths (the original EC2 launch template/ASG for
  the app tier, and a standalone load-balancer module referenced in
  `environments/dev/main.tf`'s header comment) exist only as prior
  history/reference, not as live Terraform code — worth removing outright
  in a future cleanup pass rather than leaving as a comment trail.