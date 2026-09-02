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

# --- ALB ---
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-security-group"
  description = "Allows public HTTP and HTTPS traffic to the load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public HTTP traffic"
  from_port          = 80
  to_port            = 80
  ip_protocol        = "tcp"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public HTTPS traffic"
  from_port          = 443
  to_port            = 443
  ip_protocol        = "tcp"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow ALB to forward traffic anywhere"
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

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

# --- EC2 app tier (retained for reference — no longer wired to any compute;
#     app tier moved to EKS. Left in place per the compute-module comment
#     convention rather than deleted; see punch-list item on pruning) ---
resource "aws_security_group" "ec2_app" {
  name        = "${var.name_prefix}-ec2-app-security-group"
  description = "Isolates application servers inside private subnets"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ec2-app-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "ec2_app_from_alb" {
  security_group_id           = aws_security_group.ec2_app.id
  description                 = "Allow web traffic strictly from the ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_app_from_bastion" {
  security_group_id           = aws_security_group.ec2_app.id
  description                 = "Allow admin SSH access strictly from the Bastion Host"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "ec2_app_all" {
  security_group_id = aws_security_group.ec2_app.id
  description       = "Allow instances to access the internet via NAT for updates/S3 access"
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

# --- RDS ---
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-database-security-group"
  description = "Locks database access to the app tier only — no egress rules (RDS never initiates outbound connections)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-rds-db-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2_app" {
  security_group_id           = aws_security_group.rds.id
  description                 = "Allow MySQL traffic from EC2 App Servers (legacy path — currently unused)"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2_app.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id           = aws_security_group.rds.id
  description                 = "Allow MySQL traffic from EKS nodes/pods"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.eks_cluster_sg_id
}