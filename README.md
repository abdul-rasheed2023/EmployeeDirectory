## About This Project
Employee Directory — an ASP.NET Core app built as a portfolio project 
demonstrating containerization, CI/CD, and infrastructure-as-code through 
to AWS EKS.

**Current state:** Local development app with an IEmployeeRepository 
abstraction. Container built but not yet fully verified (see Day 2).

**Target architecture:** Json-backed repository for local dev → EF Core 
with MySQL for cloud deployment. Local Docker Compose now, evolving to 
Terraform-provisioned AWS infrastructure and EKS over the next 3 months.