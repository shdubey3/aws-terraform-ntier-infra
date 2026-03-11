variable "vpc_id" {
  type = string
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "env" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name_param" {
  type = string
}

variable "db_username_param" {
  type = string
}

variable "db_password_param" {
  type = string
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ssm_access" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory"
    ]

    resources = [
      "arn:aws:ssm:*:*:parameter${var.db_username_param}",
      "arn:aws:ssm:*:*:parameter${var.db_password_param}",
      "arn:aws:ssm:*:*:parameter${var.db_name_param}",
    ]
  }
}

resource "aws_iam_policy" "ssm_access" {
  name   = "${var.name_prefix}-app-ssm-access"
  policy = data.aws_iam_policy_document.ssm_access.json
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name_prefix}-app-instance-profile"
  role = aws_iam_role.app.name
}

locals {
  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y httpd jq mysql awscli

              systemctl enable httpd
              systemctl start httpd

              DB_ENDPOINT="${var.db_endpoint}"
              DB_PORT="${var.db_port}"

              DB_NAME_PARAM="${var.db_name_param}"
              DB_USER_PARAM="${var.db_username_param}"
              DB_PASS_PARAM="${var.db_password_param}"

              DB_NAME=$(aws ssm get-parameter --name "$DB_NAME_PARAM" --query "Parameter.Value" --output text --with-decryption)
              DB_USER=$(aws ssm get-parameter --name "$DB_USER_PARAM" --query "Parameter.Value" --output text --with-decryption)
              DB_PASS=$(aws ssm get-parameter --name "$DB_PASS_PARAM" --query "Parameter.Value" --output text --with-decryption)

              cat <<'HTML' > /var/www/html/index.html
              <html>
              <head><title>App Server</title></head>
              <body>
              <h1>App Server is running</h1>
              <p>DB endpoint: ${DB_ENDPOINT}</p>
              <p>DB port: ${DB_PORT}</p>
              <p>DB name: ${DB_NAME}</p>
              </body>
              </html>
              HTML

              mysql -h "$DB_ENDPOINT" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/var/log/db-connection.log 2>&1 || true
              EOT
}

resource "aws_instance" "app" {
  count = 2

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = element(var.app_subnet_ids, count.index % length(var.app_subnet_ids))
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  associate_public_ip_address = false

  user_data = local.user_data

  tags = {
    Name        = "${var.name_prefix}-app-${count.index}"
    Environment = var.env
    Role        = "app"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

output "instance_ids" {
  value = [for i in aws_instance.app : i.id]
}

