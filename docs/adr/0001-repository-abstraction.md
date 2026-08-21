# ADR 0001: Repository Abstraction Strategy

## Status
Accepted

## Context
The application needs a data persistence approach that supports fast, 
dependency-free local development while remaining production-ready for 
cloud deployment.

## Decision
Implement `IEmployeeRepository` as an abstraction with two concrete 
implementations: `JsonEmployeeRepository` for local development (no 
external dependencies, fast iteration) and `EfEmployeeRepository` using 
EF Core against MySQL for cloud/production use. The active implementation 
is selected via configuration (`Storage:Provider`), not a code change.

## Alternatives Considered
- Single EF Core implementation from the start, using SQLite locally 
  and MySQL in production. Rejected: still requires EF migrations and 
  a DB engine locally, adding friction during early UI/controller work 
  where persistence logic wasn't the focus.
- Mocking the repository entirely in local dev with no real 
  implementation. Rejected: wanted the Json path to be genuinely usable 
  for manual testing and demos, not just unit tests.

## Trade-offs
- Two implementations to maintain and keep behaviorally consistent.
- Mitigated by testing both against the same interface contract 
  (see /tests).

## Consequences
Enables isolating infrastructure work (Docker, Terraform, EKS) from 
database-specific debugging in early months, since the app can run 
fully functional without any external DB dependency until the MySQL 
path is deliberately verified.