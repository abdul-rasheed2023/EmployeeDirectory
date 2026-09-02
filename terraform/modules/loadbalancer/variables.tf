variable "project_name" {
  type        = string
  description = "Project name used to prefix ALB and target group names"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "vpc_id" {
  type        = string
  description = "VPC the target group belongs to"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets the ALB spans"
}

variable "alb_sg_id" {
  type        = string
  description = "Security group attached to the ALB"
}
