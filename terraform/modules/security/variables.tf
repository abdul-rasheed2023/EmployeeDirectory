variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "vpc_id" {
  type        = string
  description = "VPC that these security groups belong to"
}

variable "my_ip" {
  type        = string
  description = "CIDR-masked administrator IP allowed to SSH into the bastion"
}
variable "eks_cluster_sg_id" {
  type        = string
  description = "EKS-managed cluster security group — the effective source SG for node/pod egress traffic"
} 