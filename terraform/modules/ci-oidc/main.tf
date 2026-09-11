data "aws_caller_identity" "current" {}

# GitHub's OIDC root cert thumbprint is stable and AWS no longer actually
# validates against it (STS trusts GitHub's cert chain directly since 2023),
# but the API still requires a value in thumbprint_list.
locals {
  github_oidc_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea0"
  github_oidc_url         = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.github_oidc_thumbprint]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.github_oidc_url
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  
  # sub claim format: repo:ORG/REPO:ref:refs/heads/BRANCH
  
# sub claim format (immutable, GitHub default since July 2026):
  # repo:ORG@ORG_ID/REPO@REPO_ID:ref:refs/heads/BRANCH
  allowed_subs = [for ref in var.allowed_branch_refs : "repo:${var.github_org}@${var.github_org_id}/${var.github_repo}@${var.github_repo_id}:ref:${ref}"]
 
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity","sts:TagSession"]


    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }
}

resource "aws_iam_role" "github_actions_ecr_push" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json

  # OIDC-federated, short-lived by design — no need for a long max session.
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ecr_push" {
  # GetAuthorizationToken is account-wide; ECR does not support resource-level
  # scoping for it.
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushScoped"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push-only"
  role   = aws_iam_role.github_actions_ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# ==============================================================================
# TERRAFORM APPLY PERMISSIONS
# This role is now used by CI to run full `terraform apply` — provisioning
# VPC/EKS/RDS/S3/DynamoDB/SNS/Lambda/Secrets Manager, not just pushing images.
# PowerUserAccess covers those services but explicitly excludes IAM (and
# Organizations), so it's paired with a scoped IAM statement below for the
# role/policy/OIDC-provider lifecycle actions this project's modules need
# (iam, eks, app-irsa, lb-controller-irsa, ci-oidc itself).
#
# CAVEAT: PowerUserAccess is broad — appropriate for this dev/POC stack given
# the trust policy already restricts assumption to this exact repo+branch,
# but a production setup would replace it with a hand-scoped policy limited
# to the specific resource types/ARNs this Terraform config touches.
# ==============================================================================

resource "aws_iam_role_policy_attachment" "power_user" {
  count      = var.grant_terraform_apply_permissions ? 1 : 0
  role       = aws_iam_role.github_actions_ecr_push.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "iam_management" {
  statement {
    sid    = "IAMRoleAndPolicyLifecycle"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix_for_iam_scope}*",
                 "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name_prefix_for_iam_scope}*"]
  }

  statement {
    sid    = "OIDCProviderLifecycle"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "iam_management" {
  count  = var.grant_terraform_apply_permissions ? 1 : 0
  
  name   = "terraform-iam-management"
  role   = aws_iam_role.github_actions_ecr_push.id
  policy = data.aws_iam_policy_document.iam_management.json
}
