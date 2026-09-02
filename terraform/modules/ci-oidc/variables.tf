variable "github_org" {
  description = "GitHub org or username that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "Repo name (no org prefix), e.g. EmployeeDirectory"
  type        = string
}

variable "allowed_branch_refs" {
  description = "Git refs allowed to assume the role, e.g. [\"refs/heads/dev\", \"refs/heads/main\"]"
  type        = list(string)
  default     = ["refs/heads/dev", "refs/heads/main"]
}

variable "ecr_repository_arns" {
  description = "ARNs of ECR repos CI is allowed to push to"
  type        = list(string)
}

variable "role_name" {
  description = "Name for the IAM role assumed by GitHub Actions"
  type        = string
  default     = "github-actions-ecr-push"
}

variable "create_oidc_provider" {
  description = "Set false if the token.actions.githubusercontent.com provider already exists in this account"
  type        = bool
  default     = true
}
variable "github_org_id" {
  description = "Immutable numeric ID of the GitHub org/owner (from OIDC sub claim)"
  type        = string
  default     = "148262269"
}

variable "github_repo_id" {
  description = "Immutable numeric ID of the GitHub repository (from OIDC sub claim)"
  type        = string
  default     = "1341415007"
}