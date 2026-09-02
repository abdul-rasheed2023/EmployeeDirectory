# Runbook: Rollback Procedure

## Overview
This runbook documents the rollback procedure for the Employee Directory
application. Rollback means redeploying a previously known-good image tag
rather than rebuilding or hotfixing the current broken one.

**Core principle:** rollback is a promotion in reverse — the same
immutable image promotion pattern from ADR 0004, applied to a previous
SHA tag. No rebuild, no code change required.

---

## When to roll back
- Health check (`/healthz`) returning non-200 after a deployment
- Application errors spiking in logs immediately after a release
- A critical bug found in production that cannot be hotfixed quickly
- Any situation where "get back to the last known good state" is faster
  than fixing forward

---

## Local Docker rollback (dev environment)

### Prerequisites
- Docker running locally
- Both the current (broken) and previous (known-good) image tags available

### Step 1 — Confirm current deployment is unhealthy
Verify the problem exists before taking action:
```bash
curl http://localhost:8080/healthz
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

### Step 2 — Stop and remove the broken container
```bash
docker stop employee-app
docker rm employee-app
```

### Step 3 — Redeploy the previous known-good tag
```bash
docker run -d --name employee-app -p 8080:8080 employee-directory:v1.0.0
```
Replace `v1.0.0` with the actual previous known-good tag.

### Step 4 — Verify rollback is healthy
Hit the health endpoint and confirm a 200 response:
```
GET http://localhost:8080/healthz

Expected response:
{"status": "healthy","timestamp": "2026-09-02T13:57:59.0169546Z"}
```

Confirm the correct image is running:
```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

Expected output:
NAMES          IMAGE                       STATUS          PORTS
employee-app   employee-directory:v1.0.0   Up 28 seconds   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
```

**Observed during drill (2026-09-02):** rollback from `v1.1.0` to `v1.0.0`
completed in under 30 seconds. Health check responded immediately on first
request after container start.

---

## ECR-based rollback (staging / production)

> **Note:** ECR infrastructure is provisioned in Day 33 (Month 3). This
> section documents the pattern now; the live demonstration follows once
> ECR and compute are in place.

### Prerequisites
- AWS credentials (via OIDC — no static keys)
- The SHA tag of the previous known-good image in ECR
- Access to trigger the `promote.yml` workflow

### Step 1 — Identify the previous known-good SHA
Check the GitHub Actions run history for the last successful CI run
before the broken deployment. The SHA tag is the commit SHA from that run,
visible in the "Tag and push image" step log:
```
986948598853.dkr.ecr.us-east-1.amazonaws.com/mno-group-dev-employee-directory:<sha>
```

### Step 2 — Trigger the promotion workflow in reverse
Go to: **GitHub → Actions → Promote Image → Run workflow**

Inputs:
- `source_tag`: the previous known-good SHA (e.g. `abc1234`)
- `target_environment`: `production`

Approve the Production environment gate when prompted.

The workflow pulls the SHA-tagged image and pushes it as `production-latest`
— same bits that previously ran successfully, no rebuild.

### Step 3 — Verify
- Confirm the deployment picks up the new `production-latest` tag
- Hit `/healthz` on the production endpoint
- Check application logs for clean startup

---

## What NOT to do during a rollback
- **Do not rebuild the image** — a rebuild is not a rollback. A new build
  introduces unknown variables (dependency updates, base image changes).
  Always retag a previously scanned, previously run SHA.
- **Do not skip the health check verification** — confirm the rolled-back
  version is actually healthy before closing the incident.
- **Do not delete the broken image tag from ECR** — keep it for
  post-incident analysis. Tag it `broken-<date>` if needed to avoid
  confusion, but preserve it.

---

## Post-rollback actions
1. Open a GitHub issue documenting what broke and why
2. Tag the broken image in ECR as `broken-<date>` for reference
3. Write a short post-mortem (even 5 lines) before fixing forward
4. The fix goes through the normal CI/CD pipeline — no hotfix bypasses
   branch protection or the approval gate
