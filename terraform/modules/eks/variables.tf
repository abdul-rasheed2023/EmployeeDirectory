variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the control plane (e.g. \"1.30\")"
  default     = "1.30"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets for the cluster's ENIs (needed for public ALB/NLB support)"
}

variable "private_app_subnet_ids" {
  type        = list(string)
  description = "Private subnets the cluster ENIs and worker nodes live in"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Whether the cluster API endpoint is reachable from the public internet"
  default     = true
}

variable "endpoint_private_access" {
  type        = bool
  description = "Whether the cluster API endpoint is reachable from inside the VPC"
  default     = true
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint. DEV/POC ONLY: defaults to 0.0.0.0/0 — lock this to your own IP for anything beyond a short-lived test."
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "EKS control plane log types to send to CloudWatch Logs. Empty by default to avoid CloudWatch cost on a short-lived dev cluster."
  default     = []
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group"
  default     = ["t3.micro"]
}

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}
