output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.subnets.public_subnet_ids
}

output "app_subnet_ids" {
  description = "Application private subnet IDs"
  value       = module.subnets.app_subnet_ids
}

output "db_subnet_ids" {
  description = "Database private subnet IDs"
  value       = module.subnets.db_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "app_instance_ids" {
  description = "IDs of the app EC2 instances"
  value       = module.ec2.instance_ids
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_endpoint
}

output "db_port" {
  description = "RDS database port"
  value       = module.rds.db_port
}

output "db_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

