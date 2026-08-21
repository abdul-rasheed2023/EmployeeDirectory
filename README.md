## About This Project

Employee Directory — an ASP.NET Core MVC application built as a portfolio 
project demonstrating containerization, CI/CD, and infrastructure-as-code 
through to AWS EKS.

**Current state:** Local development app with an `IEmployeeRepository` 
abstraction. Both `JsonEmployeeRepository` (local dev) and 
`EfEmployeeRepository` (MySQL, EF Core) are implemented; the EF/MySQL path 
is being verified against Docker Compose. Photo storage is abstracted 
behind `IPhotoStorageService`, with an S3-backed implementation in place.

**Target architecture:** Local Docker Compose (app + MySQL) evolving to 
Terraform-provisioned AWS infrastructure (VPC, ECR, RDS) and finally an 
EKS deployment with CI/CD via GitHub Actions.

**Repository conventions:** each milestone is tagged as a GitHub release 
(`vX.Y.0`) with architecture notes, verification steps, and known 
limitations documented in `/docs/adr` and `/docs/runbooks`.