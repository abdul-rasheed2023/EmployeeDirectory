# ==============================================================================
# SECURITY MODULE
# Security groups for the ALB, bastion host, app tier, and RDS. Rules are
# managed as standalone aws_vpc_security_group_ingress_rule/egress_rule
# resources rather than inline ingress {}/egress {} blocks on the security
# group — the current AWS provider recommendation. Standalone rules give
# each rule its own ID, support description/tags without forcing SG
# replacement, and don't fight cross-module rule attachment the way inline
# blocks do (inline blocks are "fully authoritative" — anything added to
# the same SG from outside the resource gets planned as drift and fought
# on every apply).
# ==============================================================================

# --- Bastion ---
resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-security-group"
  description = "Allows SSH access to administrators"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-bastion-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow SSH from your administrator IP address"
  from_port          = 22
  to_port            = 22
  ip_protocol        = "tcp"
  cidr_ipv4          = var.my_ip
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow bastion to communicate outbound inside the VPC"
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}


# --- RDS ---
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-database-security-group"
  description = "Locks database access to the app tier only - no egress rules (RDS never initiates outbound connections)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds-db-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id           = aws_security_group.rds.id
  description                 = "Allow MySQL traffic from EKS nodes/pods"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.eks_cluster_sg_id
}