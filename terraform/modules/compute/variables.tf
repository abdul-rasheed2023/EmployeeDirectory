variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "bastion_instance_type" {
  type        = string
  description = "Instance type for the bastion host"
}

variable "bastion_subnet_id" {
  type        = string
  description = "Public subnet the bastion host launches into"
}

variable "bastion_sg_id" {
  type        = string
  description = "Security group attached to the bastion host"
}


