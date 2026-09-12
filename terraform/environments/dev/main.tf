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

  # Explicit module-level dependency: the eks module only references
  # module.network's subnet_ids, which gives Terraform no graph edge to the
  # NAT gateway / route table resources in that module. Without this,
  # Terraform can start launching node group instances before the private
  # subnets actually have a route to the internet, causing
  # "NodeCreationFailure: Instances failed to join the kubernetes cluster".
  depends_on = [module.network]
}

module "lb_controller_irsa" {
  source            = "../../modules/lb-controller-irsa"
  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  # namespace / service_account_name left at module defaults
  # (kube-system / aws-load-balancer-controller) — matches the
  # Helm chart's default install location.
}

# lb_controller_irsa only creates the IAM role/policy for IRSA — it does not
# install the controller itself. Without this, the ingress resource below
# would sit un-reconciled forever: nothing in the cluster watches for
# Ingress objects tagged kubernetes.io/ingress.class=alb.
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  # Pin this to match the IAM policy version fetched in
  # modules/lb-controller-irsa/iam_policy.json — bump both together.
  version = "1.8.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.network.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_controller_irsa.role_arn
  }

  depends_on = [module.eks, module.lb_controller_irsa]
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  eks_node_role_arn = module.eks.node_role_arn
}

module "app_irsa" {
  source = "../../modules/app-irsa"

  name_prefix                = local.name_prefix
  common_tags                = local.common_tags
  oidc_provider_arn          = module.eks.oidc_provider_arn
  oidc_provider_url          = module.eks.oidc_provider_url
  s3_bucket_arn              = module.data.s3_bucket_arn
  dynamodb_table_arn         = module.data.dynamodb_table_arn
  data_protection_secret_arn = module.data.data_protection_secret_arn
  # namespace / service_account_name left at module defaults
  # (default / employee-directory) — matches deployment.tftpl and
  # k8s/base/serviceaccount.yaml.
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
  source                    = "../../modules/ci-oidc"
  github_org                = "abdul-rasheed2023"
  github_org_id             = "148262269"
  github_repo               = "EmployeeDirectory"
  github_repo_id            = "1341415007"
  ecr_repository_arns       = [module.ecr.repository_arn]
  name_prefix_for_iam_scope = local.name_prefix
}

# ==============================================================================
# APP MANIFESTS (k8s/base/*)
# Applied via the kubernetes provider so the whole stack — infra + app — comes
# up (and tears down) from one terraform apply. Order matters: the
# ServiceAccount must exist before the Deployment references it, and the
# app_irsa role must exist before the ServiceAccount's annotation can point
# to it — both handled via depends_on / implicit references below.
# ==============================================================================

resource "kubernetes_service_account_v1" "employee_directory" {
  metadata {
    name      = "employee-directory"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.app_irsa.role_arn
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_deployment_v1" "employee_directory" {
  metadata {
    name      = "employee-directory"
    namespace = "default"
    labels = { app = "employee-directory"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "employee-directory"
      }
    }

    template {
      metadata {
        labels = { app = "employee-directory"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.employee_directory.metadata[0].name

        security_context {
          run_as_user     = 1654
          run_as_non_root = true
          fs_group        = 1654
        }

        container {
          name  = "employee-directory"
          image = "${module.ecr.repository_url}:${var.image_tag}"

          port {
            container_port = 8080
          }

          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = "Production"
          }
          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }
          env {
            name  = "DataProtection__SecretArn"
            value = module.data.data_protection_secret_arn
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service_account_v1.employee_directory]

  # Once the HPA below takes over, it — not this resource — owns replica
  # count. Without this, every `terraform apply` would stomp whatever
  # replica count the HPA had scaled to back down to the hardcoded 2.
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_service_v1" "employee_directory" {
  metadata {
    name      = "employee-directory"
    namespace = "default"
  }

  spec {
    type = "ClusterIP"
    selector = { app = "employee-directory"
    }

    port {
      port        = 80
      target_port = 8080
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_ingress_v1" "employee_directory" {
  metadata {
    name      = "employee-directory"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.employee_directory.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # Must come after the controller is actually running, or the ALB
  # provisioning webhook/reconciliation loop has nothing to talk to.
  depends_on = [helm_release.aws_lb_controller, kubernetes_service_v1.employee_directory]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "employee_directory" {
  metadata {
    name      = "employee-directory"
    namespace = "default"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.employee_directory.metadata[0].name
    }

    min_replicas = 1
    max_replicas = 3

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.employee_directory]
}