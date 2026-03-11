data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  azs      = local.azs
  name     = "${var.project_name}-vpc"
  env      = var.environment
}

module "subnets" {
  source = "./modules/subnets"

  vpc_id            = module.vpc.vpc_id
  igw_id            = module.vpc.igw_id
  azs               = local.azs
  public_cidrs      = var.public_subnet_cidrs
  app_private_cidrs = var.app_subnet_cidrs
  db_private_cidrs  = var.db_subnet_cidrs
  name_prefix       = var.project_name
  env               = var.environment
}

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id           = module.vpc.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
  name_prefix      = var.project_name
  env              = var.environment
}

module "rds" {
  source = "./modules/rds"

  vpc_id        = module.vpc.vpc_id
  db_subnet_ids = module.subnets.db_subnet_ids
  db_sg_id      = module.security_groups.db_sg_id
  db_username   = var.db_username
  db_password   = var.db_password
  db_name       = var.db_name
  name_prefix   = var.project_name
  env           = var.environment
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project_name}/${var.environment}/db/username"
  description = "DB username for ${var.project_name}"
  type        = "SecureString"
  value       = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/${var.environment}/db/password"
  description = "DB password for ${var.project_name}"
  type        = "SecureString"
  value       = var.db_password
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/${var.project_name}/${var.environment}/db/name"
  description = "DB name for ${var.project_name}"
  type        = "String"
  value       = var.db_name
}

module "ec2" {
  source = "./modules/ec2"

  vpc_id            = module.vpc.vpc_id
  app_subnet_ids    = module.subnets.app_subnet_ids
  app_sg_id         = module.security_groups.app_sg_id
  instance_type     = var.instance_type
  name_prefix       = var.project_name
  env               = var.environment
  db_endpoint       = module.rds.db_endpoint
  db_port           = module.rds.db_port
  db_name_param     = aws_ssm_parameter.db_name.name
  db_username_param = aws_ssm_parameter.db_username.name
  db_password_param = aws_ssm_parameter.db_password.name
}

module "alb" {
  source = "./modules/alb"

  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.subnets.public_subnet_ids
  alb_sg_id           = module.security_groups.alb_sg_id
  target_instance_ids = module.ec2.instance_ids
  name_prefix         = var.project_name
  env                 = var.environment
}

