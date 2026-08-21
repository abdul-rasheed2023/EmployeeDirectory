# ADR 0002: Caching Decision — Redis Deferred

## Status
Accepted

## Context
The original portfolio roadmap included a caching layer (Redis, one read
path, defined invalidation behavior) as a Week 2 deliverable. Before adding
it, the actual need has to be established — caching exists to solve a
specific problem (read latency, database load), not to check a box on a
roadmap.

Employee Directory's access pattern is read-heavy and low-write: employee
records are created/updated infrequently, and read via a simple list/detail
view with no expensive joins, aggregations, or computed fields. There is no
current evidence of read latency or database load that a cache would
address.

## Decision
Defer Redis/caching for this project. No cache is implemented at this time.

## Alternatives Considered
- **Add Redis now, per the original roadmap.** Rejected: would add a real
  dependency (another container locally, another managed service in AWS —
  ElastiCache carries a standing cost) to solve a problem that doesn't
  exist yet. An unused or under-justified cache is also a weaker interview
  answer than a documented, reasoned deferral — "why did you cache this"
  is a much harder question to answer well than "why didn't you."
- **In-memory caching (`IMemoryCache`) instead of Redis.** Considered as a
  lighter-weight middle ground. Rejected for now on the same grounds as
  Redis — no demonstrated need yet — but flagged below as the more likely
  first step if a need does emerge, since it requires no new infrastructure.

## Trade-offs
- If read latency does become a real issue (e.g., under the load testing
  planned for Month 3), there is no caching layer already in place to
  absorb it — a cache would need to be added reactively rather than being
  ready in advance.
- Mitigated by the low likelihood of this app reaching meaningful load as a
  portfolio project, and by keeping this decision under review rather than
  closed permanently (see Revisit Conditions below).

## Consequences
No Redis container in Compose, no ElastiCache module in Terraform, no
invalidation logic to design, test, or explain. Reduces the surface area of
Month 1–2 work and keeps the infrastructure footprint minimal, consistent
with the RAG/Bedrock cost-avoidance decision made earlier in this same
portfolio effort.

## Revisit Conditions
This decision should be reopened if any of the following becomes true:
- Load testing (planned for Month 3, alongside HPA/autoscaling work) shows
  measurable read latency attributable to repeated database queries for
  the same data.
- The application grows a genuinely expensive read path (e.g., an
  aggregation, a cross-service call, a computed report) that would
  benefit from caching.
- The portfolio narrative specifically calls for demonstrating cache
  invalidation strategy as an interview topic — in which case, add it
  deliberately as a scoped exercise with a real (even if synthetic) reason,
  not folded in silently.

If revisited, default to `IMemoryCache` first (simplest, no new
infrastructure, sufficient for a single-instance or session-sticky
scenario) before reaching for Redis/ElastiCache, which only becomes
necessary once there is more than one running app instance needing a
shared cache — e.g., after the EKS deployment in Month 3, with more than
one pod replica.
