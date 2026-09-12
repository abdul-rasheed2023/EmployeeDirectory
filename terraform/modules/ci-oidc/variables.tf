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

variable "allowed_environments" {
  description = "GitHub Environment names (as set in a job's `environment:` key) allowed to assume the role. Jobs bound to an environment get a sub claim shaped repo:ORG@ID/REPO@ID:environment:NAME instead of a branch-ref sub, so these need to be listed separately (e.g. [\"Production\", \"Staging\"] for ci.yml's deploy job and promote.yml)."
  type        = list(string)
  default     = ["Production", "Staging"]
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

variable "grant_terraform_apply_permissions" {
  description = "If true, attach PowerUserAccess + a scoped IAM-management statement so this role can run a full terraform apply, not just push to ECR"
  type        = bool
  default     = true
}

variable "name_prefix_for_iam_scope" {
  description = "Resource-name prefix (e.g. \"mno-group-dev\") used to scope the IAM-management statement to only roles/policies this project creates, rather than every role in the account"
  type        = string
}

variable "create_plan_role" {
  description = "If true, create a separate read-only OIDC role trusted by PR (pull_request) runs, for use by PR-triggered `terraform plan` workflows. Kept separate from the push-only role so a PR can never assume the higher-privilege role."
  type        = bool
  default     = true
}

variable "plan_role_name" {
  description = "Name for the read-only IAM role assumed by PR-triggered GitHub Actions runs (e.g. terraform plan)"
  type        = string
  default     = "github-actions-terraform-plan"
}