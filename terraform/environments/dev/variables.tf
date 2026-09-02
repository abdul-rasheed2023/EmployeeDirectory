variable "aws_region" {
  type        = string
  description = "The target AWS region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name / suffix"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Project name used to prefix all created resources"
  default     = "mno-group"
}

variable "notification_email" {
  description = "The target email address to receive upload success messages via SNS"
  type        = string
  default     = "abdullrasheed@gmail.com"
}

variable "vpc_cidr" {
  type        = string
  description = "The foundational IP address block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two public entry subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two private application subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the two private database subnets"
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "kubernetes_version" {
  type        = string
  description = "EKS control plane Kubernetes version"
  default     = "1.33"
}

variable "eks_node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the EKS managed node group"
  default     = ["t3.medium"]
}

variable "bastion_instance_type" {
  type        = string
  description = "Hardware sizing instance type for the public bastion host"
  default     = "t3.micro"
}

variable "my_ip" {
  type        = string
  description = "Your local public IP address with CIDR mask for SSH lock down"
  default     = "0.0.0.0/0" # Replace with your actual IP, e.g., "203.0.113.50/32"
}

variable "eks_node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "eks_node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "eks_node_desired_size" {
  type        = number
  description = "Desired baseline number of worker nodes"
  default     = 2
}


