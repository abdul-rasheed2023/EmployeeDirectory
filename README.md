# Employee Directory

## What this app is

A .NET employee directory application. Originally built against a local JSON-file repository, now being migrated toward a cloud-ready architecture using EF Core + MySQL, containerized with Docker.

## Current architecture state

- **API layer:** .NET app exposing employee directory endpoints, plus a `/healthz` liveness endpoint (process-alive check only — does not currently verify DB connectivity; this is a deliberate scope decision, not a gap — see `/docs/runbooks/db-failure-recovery.md`).
- **Data layer:** `IEmployeeRepository` abstraction — local JSON-backed implementation for dev, EF Core/MySQL-backed implementation for containerized/cloud use. See `/docs/adr/0001-repository-abstraction.md`.
- **Logging:** structured logging (JSON output) on startup config and unhandled exceptions.
- **Config validation:** app fails fast at startup with a readable error if required configuration is missing.
- **Containerization:**
  - Multi-stage Dockerfile (build stage vs. slim runtime stage), runs as non-root (`USER appuser`).
  - Deterministic image tagging by short git SHA.
  - OCI image labels (`revision`, `version`, `source`).
  - `HEALTHCHECK` instruction against `/healthz`.
- **Local orchestration:** `docker-compose.yml` (app + MySQL) split into a base file plus `docker-compose.override.yml` for local secrets/env, with app and DB on an explicit named network (not the default bridge). `depends_on: condition: service_healthy` ensures the app doesn't race MySQL on startup.
- **Caching:** no cache layer (e.g. Redis) in scope — documented as a deferred decision given the app's read-heavy, low-write profile. See `/docs/adr/0002-caching-decision.md`.
- **Known behavior under DB failure:** app currently crashes if MySQL becomes unreachable mid-run and self-recovers without a restart once MySQL returns; no EF Core retry-on-failure is configured. Full details in `/docs/runbooks/db-failure-recovery.md`.

## How to run locally

**Prerequisites:** Docker and Docker Compose installed.

```bash
# Clone the repo
git clone https://github.com/abdul-rasheed2023/EmployeeDirectory.git
cd EmployeeDirectory

# Bring up the app + MySQL
docker compose up
```

The app will be available at `http://localhost:8080`. MySQL data persists across restarts via a named Docker volume.

To confirm it's running:

```bash
curl localhost:8080/healthz
# expect: 200 with a small JSON payload (status, timestamp)
```

To stop and remove the stack:

```bash
docker compose down
```

Local secrets (e.g. DB password) live in `docker-compose.override.yml`, which is **not committed to git**. No secrets are present in the base `docker-compose.yml`.

## Repository layout

````
/src              application source
/tests            test suite
/deploy           deployment-related config
/terraform        infrastructure as code (Month 3+)
/docs/adr         architecture decision records
/docs/runbooks    operational runbooks (failures, incidents, recovery steps)
/.github/workflows CI/CD pipelines (Month 2+)
```

## Status

Month 1 (Docker hardening) complete as of this README update. See `/docs/adr` and `/docs/runbooks` for the decisions and observed behavior behind the choices above. Month 2 (CI/CD) and Month 3 (Terraform) tracked separately — this document reflects app + container state only.
