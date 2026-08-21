# Runbook: EF Core / MySQL Local Verification — Debugging Log

**Date:** 21 August 2026
**Context:** Day 7 — standing up Docker Compose with MySQL and verifying the
existing `EfEmployeeRepository`/`AppDbContext` path actually works end to end.
This path was implemented earlier but had never been run against a real
database before this session.

**Outcome:** Five distinct issues found and fixed, in sequence, each blocking
the next. Documented here in the order encountered.

---

## Issue 1 — Try/catch around `AddDbContext` never fired

**Symptom:** A deliberately-written try/catch around `AddDbContext` with a
clear custom error message was supposed to fail fast if MySQL was
unreachable. It never triggered — the app would start "successfully" and
only fail later, on the first real request.

**Root cause:** `AddDbContext` registers a *lazy* factory. The options
lambda (where `ServerVersion.AutoDetect` runs) is only evaluated the first
time something in DI actually resolves `AppDbContext` — which in a typical
MVC app is the first incoming HTTP request, not application startup. The
try/catch wrapped the registration call, which always succeeds instantly
regardless of DB reachability, because nothing had tried to *use* the
connection yet.

**Fix:** Moved connectivity verification to after `app.Build()`, using
`scope.ServiceProvider.GetRequiredService<AppDbContext>()` to force
resolution at a point where it can actually be caught.

**Why it matters:** the original code looked correct and would pass a
casual review — the bug only surfaces under runtime testing, not by reading
the code. Worth checking for this same lazy-registration pattern anywhere
else DI-registered options do eager work.

---

## Issue 2 — `MySqlException` has no public constructor for a plain message

**Symptom:** Build failure: `CS1729: 'MySqlException' does not contain a
constructor that takes 1 arguments`, when trying to manually throw
`new MySqlException("some message")` for a "connected but returned false"
case.

**Root cause:** `MySqlConnector.MySqlException` is designed to be thrown
only by the driver itself on real connection errors — its constructors are
internal to the library, not exposed for application code to construct
directly.

**Fix:** Don't manufacture the exception type. Handle the "connected but
`CanConnectAsync()` returned false" case with a plain `if` block and a
regular `InvalidOperationException`. Let the `catch (MySqlException ex)`
blocks handle only genuine driver-thrown connection failures.

---

## Issue 3 — `ServerVersion.AutoDetect()` opened its own eager, unretried connection

**Symptom:** The retry loop (6 attempts, 5s delay) never actually retried —
the app crashed on the very first call, before the loop's first iteration
even printed.

**Root cause:** `GetRequiredService<AppDbContext>()` — called once, before
the retry loop starts, to force early resolution (see Issue 1) — actually
*constructs* the DbContext, which runs the options lambda, which calls
`ServerVersion.AutoDetect(connectionString)`. That call opens its own real,
synchronous, unretried connection immediately. If MySQL wasn't ready yet,
the crash happened one line before the retry loop that was supposed to
handle exactly this case.

**Fix:** Removed `ServerVersion.AutoDetect()` entirely. Since the MySQL
version is already pinned deliberately (8.4.11, matching the Compose image
tag and the planned RDS version), hardcoded it instead:
```csharp
options.UseMySql(connectionString, new MySqlServerVersion(new Version(8, 4, 11)))
```
This removes all network I/O from DbContext *construction* — the only place
a real connection is attempted is inside the retry loop's
`CanConnectAsync()` call, which is the single point of control the design
intended.

**Why it matters:** a "safe-looking" library call did eager I/O outside
where it was expected to. Same underlying category as Issue 1 — something
assumed to be lazy/deferred was actually eager. Worth generalizing as a
pattern to watch for.

---

## Issue 4 — `localhost` vs. `mysql` as the connection hostname

**Symptom:** App inside `docker compose` retried all 6 attempts and failed
with "Unable to connect to any of the specified MySQL hosts" — despite the
exact same connection string working moments earlier when running
`dotnet ef database update` directly on Windows.

**Root cause:** Host-machine networking and container-to-container
networking are different address spaces. `Server=localhost` correctly
pointed at the MySQL container *when run from Windows*, because Docker maps
the container's port 3306 out to the host's `localhost:3306`. But once the
app itself is running *inside* a container on the same Compose network,
`localhost` refers to the app container itself — not its sibling MySQL
container. Containers on the same Compose network reach each other by
**service name** (`mysql`, per `docker-compose.yml`), not `localhost`.

**Fix:** Two separate connection strings depending on context:
- Running EF CLI commands from the host (`dotnet ef ...`) → `Server=localhost`
- Running the app inside `docker compose` → `Server=mysql`

Documented in `dev-mysql.ps1` and `.env` so this isn't re-discovered from
scratch later.

**Why it matters:** this is the exact same principle Kubernetes services use
(DNS-based service discovery, not localhost) — good foundation for Month 3.

---

## Issue 5 — `dotnet ef` commands silently defaulted to Json mode

**Symptom:** `dotnet ef migrations list` failed with "Unable to resolve
service for type DbContextOptions... while attempting to activate
AppDbContext" — even though MySQL mode had been working moments earlier in
the running app.

**Root cause:** `dotnet ef` boots the actual application to discover
`DbContext` types, running the same `Program.cs` startup logic as a normal
run. Since `Storage__Provider` wasn't set as an environment variable *in
that specific terminal session*, it defaulted to `Json` — and in Json mode,
`AddDbContext<AppDbContext>` is never called at all (it's inside the
`if (useMySql)` block). So `dotnet ef` found no registered DbContext,
because none was registered in that mode.

**Fix:** Every `dotnet ef` command needs `Storage__Provider=MySql` and
`ConnectionStrings__Default` set in the same terminal session first. Wrote
`dev-mysql.ps1` (dot-sourced) to set both reliably, removing the "forgot to
set env vars" failure mode going forward.

---

## Migrations note

`dotnet ef database update` succeeding does not by itself confirm tables
were created — if zero migrations exist in the project, it succeeds
trivially with nothing to apply. Confirmed via `dotnet ef migrations list`
before assuming the schema existed; generated `InitialCreate` when the list
came back empty.

## Tooling note (non-blocking)

MySQL Workbench crashed on connect (test connection succeeded, but opening
a session crashed the app) — likely a version-compatibility issue between
Workbench and MySQL 8.4.11, or an SSL handshake issue with the server's
self-signed cert. Not investigated further; switched to `docker exec`
direct queries to unblock verification, with DBeaver installed as a GUI
option to revisit later, not urgent.

## Interview angle

This sequence is strong material for a "walk me through debugging a tricky
issue" question — five compounding, individually-explainable problems, each
found through actual runtime testing rather than code review alone. The
common thread across Issues 1 and 3 (things assumed lazy/deferred turning
out to be eager) is worth naming explicitly if asked to generalize a lesson
from this.
