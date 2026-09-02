variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names in this module"
}

variable "common_tags" {
  type        = map(string)
  description = "Tags merged onto every resource in this module"
}

variable "private_data_subnet_ids" {
  type        = list(string)
  description = "Private data subnets RDS is placed in"
}

variable "rds_sg_id" {
  type        = string
  description = "Security group attached to the RDS instance"
}
