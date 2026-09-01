output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "ec2_app_sg_id" {
  value = aws_security_group.ec2_app.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}
