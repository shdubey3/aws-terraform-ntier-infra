variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks for app private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for DB private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into app instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_username" {
  description = "Master username for the RDS database (only used to create secret)"
  type        = string
  sensitive   = true
  default     = "appuser"
}

variable "db_password" {
  description = "Master password for the RDS database (only used to create secret)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "appdb"
}

variable "instance_type" {
  description = "EC2 instance type for app servers"
  type        = string
  default     = "t3.micro"
}

