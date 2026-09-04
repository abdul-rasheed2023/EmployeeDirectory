# ==============================================================================
# DEV ENVIRONMENT
# Wires the centralized modules together for the dev environment. This file
# should stay thin - resource logic lives in modules/, this just supplies
# environment-specific values and connects module outputs to module inputs.
#
# App tier: originally EC2/ASG behind an ALB (modules/compute + loadbalancer),
# retired in favor of EKS (modules/eks) - the old modules are left in the repo
# for reference but are no longer wired in here. compute/ now only builds the
# bastion host.
# ==============================================================================

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix               = local.name_prefix
  common_tags               = local.common_tags
  vpc_cidr                  = var.vpc_cidr
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  eks_cluster_name          = local.cluster_name
}

module "security" {
  source = "../../modules/security"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  vpc_id            = module.network.vpc_id
  my_ip             = var.my_ip
  eks_cluster_sg_id = module.eks.cluster_security_group_id
}

module "data" {
  source = "../../modules/data"

  name_prefix             = local.name_prefix
  common_tags             = local.common_tags
  private_data_subnet_ids = module.network.private_data_subnet_ids
  rds_sg_id               = module.security.rds_sg_id
}

module "iam" {
  source = "../../modules/iam"

  name_prefix        = local.name_prefix
  s3_bucket_arn      = module.data.s3_bucket_arn
  dynamodb_table_arn = module.data.dynamodb_table_arn
}

module "compute" {
  source = "../../modules/compute"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  bastion_instance_type = var.bastion_instance_type
  bastion_subnet_id     = module.network.public_subnet_ids[0]
  bastion_sg_id         = module.security.bastion_sg_id
}

module "eks" {
  source = "../../modules/eks"

  name_prefix            = local.name_prefix
  common_tags            = local.common_tags
  cluster_name           = local.cluster_name
  kubernetes_version     = var.kubernetes_version
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids
  node_instance_types    = var.eks_node_instance_types
  node_desired_size      = var.eks_node_desired_size
  node_min_size          = var.eks_node_min_size
  node_max_size          = var.eks_node_max_size
  # DEV/POC ONLY: leaves the API endpoint open to 0.0.0.0/0 (module default).
  # Lock public_access_cidrs down to your own IP for anything beyond a short
  # provision-verify-destroy test.
}

module "lb_controller_irsa" {
  source = "../../modules/lb-controller-irsa"
  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  # namespace / service_account_name left at module defaults
  # (kube-system / aws-load-balancer-controller) — matches the
  # Helm chart's default install location.
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  eks_node_role_arn = module.eks.node_role_arn
}

module "notifications" {
  source = "../../modules/notifications"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  notification_email  = var.notification_email
  lambda_role_arn     = module.iam.lambda_role_arn
  dynamodb_table_name = module.data.dynamodb_table_name
  s3_bucket_id        = module.data.s3_bucket_id
  s3_bucket_arn       = module.data.s3_bucket_arn
}
module "ci_oidc" {
  source              = "../../modules/ci-oidc"
  github_org          = "abdul-rasheed2023"
  github_org_id       = "148262269"
  github_repo         = "EmployeeDirectory"
  github_repo_id      = "1341415007"
  ecr_repository_arns = [module.ecr.repository_arn]
}