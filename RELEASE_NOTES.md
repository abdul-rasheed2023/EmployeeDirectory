# Release Notes

## v1.0.0 — Month 1 Portfolio Release

Containerized ASP.NET Core Employee Directory application with a repository abstraction layer, EF Core/MySQL data access, and environment-separated Docker configuration. This closes out Month 1 of the EKS/Terraform portfolio build.

### What's in
- ASP.NET Core MVC Employee Directory app with `IEmployeeRepository` abstraction (JSON-backed for local dev, EF Core/MySQL for containerized/cloud environments)
- Multi-stage Dockerfile with image labels, healthcheck, and deterministic tagging
- `.dockerignore` hardening for lean build context
- EF Core `InitialCreate` migration verified end-to-end against MySQL, with lazy `DbContext` validation and eager-connection issue fixes
- Environment separation for the compose stack, with dynamic database onboarding and health checks
- ADRs documenting key architecture decisions: repository abstraction rationale, and deferral of Redis/caching (no current read-latency justification)
- Dev-mysql helper script for local database bring-up
- Runbook documentation for local EF Core/MySQL verification and debugging

### Known-missing (by design — scoped for later months)
- No CI/CD pipeline yet — build, test, and quality gates land in Month 2
- No automated test suite (unit/integration tests not yet written)
- No cloud deployment yet — app runs locally via Docker Compose only; ECR push and EKS cluster provisioning are in progress but not complete
- No caching layer (Redis) — explicitly deferred per ADR, not an oversight
- No CI-built image (current images are built and tagged locally only)

### What Month 2 covers
- GitHub Actions CI pipeline: build/test workflow triggered on PR
- Test coverage reporting (coverlet) and NuGet dependency caching
- Quality gates: `dotnet format` verification and warnings-as-errors
- CI-built Docker images tagged by commit SHA

---

*Tag: `v1.0.0` · Branch: `main`*
