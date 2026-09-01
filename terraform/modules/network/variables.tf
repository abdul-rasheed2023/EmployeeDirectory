variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two public subnets"
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two private application subnets"
}

variable "private_data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two private database subnets"
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name — used to tag subnets so EKS/ALB controller can auto-discover them. Pass \"\" to skip EKS tagging entirely."
  default     = ""
}
