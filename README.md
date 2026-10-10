# Terraform AWS Infrastructure as Code

Production-style AWS infrastructure built with reusable Terraform modules, remote state (S3 + DynamoDB locking) and three isolated environments (dev / staging / prod).

## Architecture

```
                         Internet
                             |
                    +--------v--------+
                    |  ALB (public)   |   sg: 80 from 0.0.0.0/0
                    +--------+--------+
                             |
        VPC 10.x.0.0/16      |
  +--------------------------|---------------------------+
  |  Public subnets (2-3 AZs): ALB, NAT Gateway(s)       |
  |                          |                           |
  |  Private subnets (2-3 AZs)                           |
  |   +----------------------v------------+              |
  |   | Auto Scaling Group (EC2, nginx)   |  sg: 80 from ALB sg only
  |   +----------------------+------------+              |
  |                          |                           |
  |   +----------------------v------------+              |
  |   | RDS MySQL (encrypted, private)    |  sg: 3306 from app sg only
  |   +-----------------------------------+              |
  +------------------------------------------------------+

  IAM role (SSM access, no SSH keys)  -> EC2 instance profile
  State: S3 (versioned, encrypted) + DynamoDB lock table
```

## Repository layout

```
bootstrap/            one-time creation of the S3 bucket + DynamoDB lock table
modules/
  vpc/                VPC, public/private subnets, IGW, NAT, route tables
  iam/                EC2 role + instance profile (SSM)
  alb/                Application Load Balancer, target group, listener, SG
  compute/            Launch template + Auto Scaling Group, SG, IMDSv2, encrypted EBS
  rds/                MySQL, subnet group, SG, AWS-managed password (Secrets Manager)
environments/
  dev/ staging/ prod/ same code, different terraform.tfvars + separate state key
ansible/              optional post-provision configuration (nginx hardening)
docs/                 resume bullets, interview Q&A, cost notes
```

## Environment differences

| Setting | dev | staging | prod |
|---|---|---|---|
| VPC CIDR | 10.10.0.0/16 | 10.20.0.0/16 | 10.30.0.0/16 |
| AZs | 2 | 2 | 3 |
| NAT gateways | 1 shared | 1 shared | 1 per AZ |
| Instance type | t3.micro | t3.small | t3.medium |
| ASG min/desired/max | 1/1/2 | 1/2/3 | 2/3/6 |
| RDS | single-AZ | single-AZ | Multi-AZ, deletion protection, 7-day backups |

## Cost warning

Applying this creates **billable** resources. The big ones: NAT Gateway (~$0.045/hr each, about $33/month), ALB (~$16/month), RDS (db.t3.micro may fall under free tier on new accounts), EC2. A dev environment left running costs roughly **$55-70/month**. Prod costs several times more. **Run `terraform destroy` as soon as you finish demoing.** To cut cost set `enable_nat_gateway = false` and `enable_rds = false` in dev (instances will not be able to install nginx without NAT, so use a pre-baked AMI in that case).

## Usage (Windows PowerShell)

Prerequisites: Terraform >= 1.5, AWS CLI configured (`aws configure` or SSO). Never put keys in code.

### 1. Create the remote state backend (once)

```powershell
cd bootstrap
terraform init
terraform apply -var "state_bucket_name=<your-globally-unique-bucket>"
```

### 2. Deploy an environment

```powershell
cd ..\environments
copy backend.hcl.example backend.hcl      # edit bucket name
cd dev
terraform init -backend-config=..\backend.hcl
terraform plan -out dev.tfplan
terraform apply dev.tfplan
```

Test: open the `alb_url` output in a browser.

### 3. Tear down

```powershell
terraform destroy
```

### Validate without touching AWS

```powershell
terraform fmt -check -recursive
cd environments\dev
terraform init -backend=false
terraform validate
```

## Key design decisions (interview talking points)

- **Modules over copy-paste**: each module has one job and is reused by all three environments.
- **Remote state + locking**: S3 versioning allows recovery; DynamoDB lock prevents two engineers applying at once.
- **One state file per environment**: a bad dev change cannot corrupt prod state.
- **Least privilege networking**: security groups chain ALB -> app -> DB by referencing SGs, not CIDRs.
- **No secrets in code**: RDS password is generated and stored in Secrets Manager (`manage_master_user_password`).
- **No SSH**: instances are reached through SSM Session Manager; IMDSv2 is enforced; EBS is encrypted.
- **No hardcoded AMI IDs**: the latest Amazon Linux 2023 AMI is resolved through an SSM public parameter.
- **Prod HA**: 3 AZs, NAT per AZ, Multi-AZ RDS, deletion protection.

## Possible extensions

- EKS module (replace the compute module), HTTPS with ACM + Route 53, CloudWatch alarms,
  GitHub Actions pipeline running `fmt`/`validate`/`tflint`/`tfsec`/`plan` on pull requests.
