# ==============================================================================
# COMPUTE MODULE
# Bastion host only. The EC2 launch template + Auto Scaling Group that used
# to front the app tier were retired when the app moved to EKS — kept as a
# public jump box for ad-hoc VPC access (e.g. reaching RDS directly), not
# for running application workloads.
# ==============================================================================

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.bastion_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.bastion.name
  tags = merge(var.common_tags, { Name = "${var.name_prefix}-bastion-host" })
}

#resource "aws_instance" "bastion" {
  # ... existing config ...
 # iam_instance_profile = aws_iam_instance_profile.bastion.name
#}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name_prefix}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}