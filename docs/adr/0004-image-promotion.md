# ADR 0004: Immutable Image Promotion Pattern

## Status
Accepted

## Context
The CI pipeline (Day 17–19) builds a Docker image on every push to `main`,
tags it with the commit SHA, scans it for vulnerabilities, and pushes it
to ECR. As the project grows toward multiple environments (dev → staging →
production), a decision is needed: does each environment get a freshly
built image, or does a single build artifact travel through all environments?

## Decision
**One build, promoted by retagging — never rebuilt per environment.**

The image built and scanned by CI against a specific commit SHA is the
canonical artifact for that commit. Promotion to a higher environment means
pulling that SHA-tagged image from ECR and pushing it under a new
environment tag (e.g. `staging-latest`, `production-latest`). No new
`docker build` is run at promotion time.

The promotion is implemented as a manually triggered GitHub Actions workflow
(`.github/workflows/promote.yml`) with two inputs:
- `source_tag` — the commit SHA tag from a passing CI run
- `target_environment` — `staging` or `production`

Promotion to `production` requires approval via the GitHub `Production`
environment gate before the retagging steps execute.

## Consequences
- The image that reaches production is **byte-for-byte identical** to the
  image that was scanned in CI — no risk of a rebuild introducing a
  different dependency version or layer due to a non-deterministic build
  environment.
- Vulnerability scan results from CI are valid for the promoted image —
  no re-scan needed at promotion time (though a re-scan on pull is
  acceptable as a defence-in-depth measure once Scan on Push is enabled
  in ECR, which it is — see the ECR module).
- Rollback is a promotion in reverse: retag the previous known-good SHA
  as `production-latest` and redeploy. No rebuild required.
- The `source_tag` input must be a SHA from a CI run that passed all
  gates — build, test, coverage, formatting, and Trivy scan. This is
  enforced by convention (documented in the runbook) not by code today;
  a future improvement would validate the SHA against a CI run status
  via the GitHub API before retagging.

## Alternatives Considered
- **Rebuild per environment** — rejected: introduces the risk that the
  artifact tested in CI is not the artifact running in production. A
  non-deterministic base image update or transitive dependency change
  between build and promotion would be invisible.
- **Single `latest` tag, no SHA pinning** — rejected: `latest` is
  mutable, makes rollback ambiguous ("which latest?"), and breaks
  auditability. SHA tags are immutable by construction.
- **Use ECR image manifest copy (no docker pull/push round-trip)** —
  valid future improvement: `aws ecr batch-get-image` + 
  `aws ecr put-image` copies the manifest server-side without pulling
  layers to the runner. Deferred for simplicity; the pull/retag/push
  pattern is more universally understood and sufficient at this scale.
