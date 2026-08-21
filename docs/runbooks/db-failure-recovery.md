# Runbook: Database Failure Recovery

**Date:** 2026-08-21
**Scope:** Employee Directory app — behavior when the MySQL container goes down and comes back, observed via `docker compose`.

## Test performed

1. Brought up the full stack with `docker compose up`.
2. Stopped the MySQL container mid-run while the app was live.
3. Observed app behavior with MySQL down.
4. Restarted the MySQL container.
5. Observed app behavior after MySQL came back — no app restart performed.

## Observed behavior

### While MySQL was down
- The main app crashed. Hitting `http://localhost:8080/` failed — the app did not stay up and serve a degraded response, it went down with the DB.
- `GET /healthz` continued to return `200`. The health check does not query the database, so it reported healthy while the app itself was actually unusable. This is a false positive — a health check consumer (e.g. an ALB target group) would have kept routing traffic here.
- No retry attempts were observed. EF Core is not configured with `EnableRetryOnFailure()`, so the first failed DB call surfaced as an immediate failure rather than a series of backoff retries.

### After MySQL came back
- The app recovered and started serving requests again **without a manual restart**. No intervention was needed once the DB was reachable again.

## Root causes

| Symptom | Cause |
|---|---|
| Main app crashed on DB loss | No resilience/retry layer around DB calls; an unhandled DB exception took the whole app down rather than degrading gracefully |
| `/healthz` returned 200 during the outage | Health check only confirms the process is alive — it doesn't check DB connectivity |
| No retries observed | `EnableRetryOnFailure()` is not configured on the EF Core MySQL provider |
| App recovered without restart | The process itself never fully died (or was restarted by Compose's restart policy) — once a fresh DB connection could be established, normal operation resumed |

## Follow-ups worth doing (not yet implemented)

- Make `/healthz` DB-aware — add a lightweight DB ping (or check the last successful DB call) so the health check reflects actual app health, not just process liveness. This matters most once an ALB/target group is in front of this (Month 3, Day 37).
- Evaluate `EnableRetryOnFailure()` on the MySQL provider so transient DB blips don't immediately surface as failures to the caller.
- Decide whether a crash-and-recover pattern (current behavior) is actually acceptable vs. whether the app should catch the DB exception and serve a degraded response instead. Crash-and-recover is a legitimate, defensible choice for a low-traffic internal tool — but it should be a documented decision, not an accident.

## Interview note

This is a genuine observed failure, not a hypothetical: false-positive health check during a real outage, no retry logic, and a self-healing recovery once the dependency returned. Good raw material for a "tell me about a time you found and diagnosed a production-like issue" answer.
