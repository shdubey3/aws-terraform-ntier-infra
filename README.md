# AWS Terraform Infra (us-west-1)

## Architecture overview

This repository provisions a minimal but production-style, highly available stack in AWS `us-west-1`:

- **VPC** with CIDR `10.0.0.0/16`
- **Two AZs** used for:
  - Public subnets (for ALB and NAT Gateway)
  - Private app subnets (for EC2 instances)
  - Private DB subnets (for RDS)
- **Internet Gateway** attached to the VPC
- **NAT Gateway** in a public subnet for outbound internet from app subnets
- **Route tables**:
  - Public RT → IGW, associated with public subnets
  - App RT → NAT Gateway, associated with app private subnets
  - DB RT → no default internet route, associated with DB subnets
- **Security groups**:
  - `alb-sg`: HTTP from internet, forwards to app
  - `app-sg`: HTTP from ALB, SSH from configurable CIDR, outbound to DB + internet via NAT
  - `db-sg`: MariaDB from `app-sg` only
- **Application Load Balancer (ALB)**:
  - Deployed in public subnets
  - HTTP listener on port 80
  - Target group pointing at app EC2 instances
- **EC2 app tier**:
  - Two `t2.micro` instances in private app subnets
  - No public IPs
  - IAM instance profile with least-privilege access to read DB credentials from SSM Parameter Store
  - User data installs a simple HTTP server and renders DB connection info
- **RDS (MariaDB)**:
  - Single `db.t3.micro` instance in DB subnets
  - Not publicly accessible
  - Easy to extend to multi-AZ later
- **Credentials**:
  - Stored securely in **AWS Systems Manager Parameter Store (SecureString)**
  - App instances access only the specific parameters via IAM

### Textual architecture diagram

```text
Internet
   |
   v
ALB (public subnets, alb-sg)
   |
   v
App EC2 (private app subnets, app-sg)
   |
   v
RDS MariaDB (private DB subnets, db-sg)

Public RT  -> IGW
App RT     -> NAT Gateway -> IGW
DB RT      -> no internet route
```

## Files and modules

Top level:

- `versions.tf` – Terraform and provider version constraints
- `providers.tf` – AWS provider, region (default `us-west-1`) and default tags
- `variables.tf` – shared variables (VPC CIDR, subnet CIDRs, DB creds, etc.)
- `main.tf` – wiring of all modules
- `outputs.tf` – key outputs (VPC, subnets, ALB, EC2, RDS)
- `README.md` – this documentation

Modules:

- `modules/vpc` – VPC + Internet Gateway
- `modules/subnets` – public, app, DB subnets, NAT Gateway, and route tables
- `modules/security-groups` – `alb-sg`, `app-sg`, `db-sg`
- `modules/ec2` – IAM role/profile, app EC2 instances, user data
- `modules/alb` – ALB, target group, listener, and attachments
- `modules/rds` – DB subnet group + MariaDB RDS instance

## Credentials strategy

### Storage

DB credentials are **not** hardcoded into user data or the app code. Instead:

- Terraform creates three SSM Parameters:
  - `/\<project>/\<env>/db/username` – `aws_ssm_parameter.db_username` (SecureString)
  - `/\<project>/\<env>/db/password` – `aws_ssm_parameter.db_password` (SecureString)
  - `/\<project>/\<env>/db/name` – `aws_ssm_parameter.db_name` (String)

These values come from the Terraform variables `db_username`, `db_password`, and `db_name`. The password is only used to create the secret and is not exposed via outputs.

### EC2 IAM access

- `modules/ec2` creates:
  - An IAM role for the app instances with a trust policy for `ec2.amazonaws.com`
  - An IAM policy that allows `ssm:GetParameter*` on just the three DB parameters
  - An instance profile attached to the app instances

This is **least privilege**: the instances can only read the DB-related parameters and nothing else.

### User data usage

In `modules/ec2`:

- User data script:
  - Installs `httpd`, `awscli`, `jq`, and `mysql` client
  - Uses `aws ssm get-parameter --with-decryption` to read DB name, user, and password
  - Renders `/var/www/html/index.html` containing the DB endpoint, port, and name
  - Attempts a simple `SELECT 1;` against the DB and logs to `/var/log/db-connection.log`

This shows how a real application would retrieve credentials via AWS SDK/CLI instead of embedding them.

## SSH access model

- App EC2 instances are launched **without public IPs** in private subnets.
- You have two options to SSH:
  1. **Bastion/jump host** in a public subnet (recommended for production).
  2. Temporarily create a public instance or modify `ssh_allowed_cidr` to allow your IP and attach an Elastic IP to a bastion.

This configuration leaves room for you to add a bastion module without changing the app instances.

## Required inputs

Most inputs have sensible defaults but can be overridden:

- `project_name` – project prefix used in naming (default: `cloud-native-app`)
- `environment` – environment tag (default: `prod`)
- `aws_region` – AWS region (default: `us-west-1`)
- `vpc_cidr` – VPC CIDR (default: `10.0.0.0/16`)
- `public_subnet_cidrs` – list of public subnet CIDRs in two AZs
- `app_subnet_cidrs` – list of private app subnet CIDRs in two AZs
- `db_subnet_cidrs` – list of private DB subnet CIDRs in two AZs
- `ssh_allowed_cidr` – CIDR allowed for SSH into app instances (default: `0.0.0.0/0`, change for production)
- `db_username` – DB master username (sensitive)
- `db_password` – DB master password (sensitive, required)
- `db_name` – DB name (default: `appdb`)
- `instance_type` – app EC2 instance type (default: `t2.micro`)

## Important outputs

From `outputs.tf`:

- `vpc_id` – ID of the VPC
- `public_subnet_ids` – list of public subnet IDs
- `app_subnet_ids` – list of app private subnet IDs
- `db_subnet_ids` – list of DB private subnet IDs
- `alb_dns_name` – DNS name of the ALB
- `app_instance_ids` – IDs of the app EC2 instances
- `db_endpoint` – RDS endpoint hostname
- `db_port` – RDS port (3306)
- `db_name` – database name

## How to use

### 1. Configure AWS credentials

Ensure your AWS credentials are available via one of:

- `~/.aws/credentials`
- Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
- AWS SSO/profile configuration

### 2. Initialize

```bash
cd aws-terraform-infra
terraform init
```

### 3. Plan

You must provide a secure DB password (either via CLI or a `.tfvars` file).

Example using CLI variables:

```bash
terraform plan \
  -var="project_name=cloud-native-app" \
  -var="environment=prod" \
  -var="db_password=CHANGEME-strong-password"
```

Or using a `prod.tfvars`:

```hcl
project_name = "cloud-native-app"
environment  = "prod"
db_username  = "appuser"
db_password  = "CHANGEME-strong-password"
ssh_allowed_cidr = "x.x.x.x/32"
```

Then:

```bash
terraform plan -var-file="prod.tfvars"
```

### 4. Apply

```bash
terraform apply -var-file="prod.tfvars"
```

After a successful apply, Terraform will print:

- ALB DNS name – use it in a browser to hit the app via HTTP
- RDS endpoint and DB info – for connecting with a DB client if needed

### 5. Destroy

When done with the environment:

```bash
terraform destroy -var-file="prod.tfvars"
```

## Free-tier and cost notes

- EC2: `t2.micro` is free-tier eligible for the first 12 months (depending on your AWS account).
- RDS: `db.t3.micro` is commonly free-tier eligible; confirm in the AWS docs for your account.
- NAT Gateway and data transfer are **not** free; running this continuously will incur costs.
- ALB also incurs hourly and data charges.

Use this configuration as a starting point and tear it down when not needed in non-production accounts.

