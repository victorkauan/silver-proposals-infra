output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnets (ALB and ECS tasks), one per availability zone."
  value       = aws_subnet.public[*].id
}

output "isolated_subnet_ids" {
  description = "Subnets without any internet route (database), one per availability zone."
  value       = aws_subnet.isolated[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}
