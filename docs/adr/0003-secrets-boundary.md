# ADR 0003: Secrets Boundary — What Goes in Secrets Manager vs. Config

## Status
Accepted

## Context
The application currently reads configuration from `appsettings.json` /
`appsettings.{Environment}.json` and environment variables. No secrets
infrastructure exists yet — RDS, ElastiCache, and Secrets Manager are
Month 3–4 work. This ADR is written ahead of that infrastructure so the
boundary is decided deliberately, not discovered by accident when the
first real credential needs a home.

The goal is a clear, defensible line: what counts as a *secret* (goes in
AWS Secrets Manager, injected at runtime, never in source control) versus
what counts as *environment-specific configuration* (goes in
`appsettings.{Environment}.json` or plain environment variables, safe to
commit).

## Decision

**Goes in AWS Secrets Manager:**
- Database connection strings / credentials (once RDS exists, Month 4)
- Any third-party API keys or tokens the app calls at runtime
- The ASP.NET Core Data Protection key ring persistence key material
  (tracked separately — see the deferred Data Protection fix from Day 17;
  this ADR establishes *where* it will live once implemented: Secrets
  Manager or a mounted Kubernetes Secret, decided at Month 6 EKS work)

**Goes in `appsettings.{Environment}.json` / environment variables
(non-secret, safe to commit):**
- `ASPNETCORE_ENVIRONMENT`
- `ASPNETCORE_URLS`
- Feature flags
- Non-sensitive service URLs / endpoints
- Logging levels and non-sensitive operational config

**Explicitly NOT a secret, and NOT Secrets Manager's job:**
- CI's AWS identity (the GitHub Actions OIDC role from Day 19). This is
  short-lived, federated identity for the pipeline itself, not an
  application secret — it lives in the IAM role trust policy and the
  workflow's `permissions:` block, never as a stored credential anywhere.

## Consequences
- No secret value is ever committed to the repo or baked into a Docker
  image layer.
- Local development uses `appsettings.Development.json` (gitignored) or
  user secrets for anything that would otherwise be a real credential in
  other environments — since no real secrets exist locally yet, this is
  currently moot but stated for when it stops being moot.
- When RDS and Secrets Manager are provisioned in Month 4, the app will
  read connection strings via the AWS SDK / `Microsoft.Extensions.Configuration.AWS`
  Secrets Manager provider at startup — not hand-rolled retrieval code.
- Secrets Manager's automatic rotation will be enabled for RDS credentials
  once provisioned in Month 4 — rotation strategy to be documented in
  ADR 0007 (RDS provisioning).
- IAM roles (not access keys) are the access mechanism for both CI (OIDC)
  and the running application (IRSA once on EKS, Month 6) — consistent
  with the AWS Solutions Architect Professional practices this project is
  meant to demonstrate.

## Alternatives Considered
- **Everything in Secrets Manager, including non-sensitive config** —
  rejected: adds AWS API calls and cost for values that carry no
  confidentiality requirement, and makes local dev harder for no benefit.
- **`.env` files for secrets** — rejected: no built-in rotation, no audit
  trail, and easy to accidentally commit despite `.gitignore` discipline.
