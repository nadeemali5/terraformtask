output "ALB_DNS_NAME" {
  value = aws_lb.app_lb.dns_name
}

output "PRI_SUB_NW_ADDR_1" {
  value = aws_subnet.private_subnet_1.cidr_block
}

output "PRI_SUB_NW_ADDR_2" {
  value = aws_subnet.private_subnet_2.cidr_block
}

output "PUB_SUB_NW_ADDR_1" {
  value = aws_subnet.public_subnet_1.cidr_block
}

output "PUB_SUB_NW_ADDR_2" {
  value = aws_subnet.public_subnet_2.cidr_block
}
