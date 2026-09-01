output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_app_subnet_ids" {
  value = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
}

output "private_data_subnet_ids" {
  value = [aws_subnet.private_data_1.id, aws_subnet.private_data_2.id]
}

output "nat_gateway_id" {
  value = aws_nat_gateway.nat.id
}
