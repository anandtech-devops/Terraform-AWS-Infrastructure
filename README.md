# Terraform AWS Infrastructure as Code

A portfolio and learning project demonstrating reusable Terraform modules and isolated AWS environments (dev, staging, and prod). The configuration is designed to model common cloud architecture patterns; **it has been validated with Terraform formatting/validation checks but has not been deployed or production-tested**.

> **Cost and safety first:** Do not run `terraform apply` until you have reviewed the plan and current AWS pricing. This project can create billable resources, including NAT Gateways, an Application Load Balancer, EC2 Auto Scaling resources, RDS, and a state backend. Example values are templates, not a recommendation to deploy every environment.

## Architecture

```
                         Internet
                             |
                    +--------v--------+
                    |  ALB (public)   |   HTTP port 80
                    +--------+--------+
                             |
        VPC 10.x.0.0/16      |
  +--------------------------|---------------------------+
  |  Public subnets (2-3 AZs): ALB, NAT Gateway(s)       |
  |                          |                           |
  |  Private subnets (2-3 AZs)                           |
  |   +----------------------v------------+              |
  |   | Auto Scaling Group (EC2, nginx)   |  HTTP from ALB only
  |   +----------------------+------------+              |
  |                          |                           |
  |   +----------------------v------------+              |
  |   | RDS MySQL (encrypted, private)    |  MySQL from app SG
  |   +-----------------------------------+              |
  +------------------------------------------------------+

  IAM role (SSM access, no SSH keys) -> EC2 instance profile
  State: S3 (versioned, encrypted) + DynamoDB lock table
```

**Important security note:** the current ALB listener is HTTP-only. Treat this as a learning/demo configuration, not a production-ready internet-facing service. Add HTTPS with ACM and review all security controls before any real deployment.

## Repository layout

```
bootstrap/            one-time creation of the S3 state bucket and DynamoDB lock table
modules/
  vpc/                VPC, public/private subnets, IGW, NAT, route tables
  iam/                EC2 role and instance profile (SSM)
  alb/                Application Load Balancer, target group, listener, security group
  compute/             Launch template, Auto Scaling Group, IMDSv2, encrypted EBS
  rds/                MySQL, subnet group, security group, AWS-managed password
environments/
  dev/ staging/ prod/ separate state keys and environment-specific example variables
  backend.hcl.example remote-state backend settings template
ansible/              optional post-provision configuration
docs/                 resume bullets and interview notes
```

## Environment design

| Setting | dev | staging | prod |
|---|---|---|---|
| VPC CIDR | 10.10.0.0/16 | 10.20.0.0/16 | 10.30.0.0/16 |
| Availability zones | 2 | 2 | 3 |
| NAT gateways | 1 shared | 1 shared | 1 per AZ |
| EC2 instance type | t3.micro | t3.small | t3.medium |
| ASG min / desired / max | 1 / 1 / 2 | 1 / 2 / 3 | 2 / 3 / 6 |
| RDS | Single-AZ | Single-AZ | Multi-AZ, deletion protection, 7-day backups |

Each environment has a `terraform.tfvars.example` template. Copy it to `terraform.tfvars` and adjust values for your own account. The real `terraform.tfvars` file is ignored by Git.

## Cost warning

This configuration can create **billable AWS resources**. NAT Gateways and the ALB can incur ongoing charges even when traffic is low; EC2, EBS, RDS, data transfer, and the state backend may add more. The exact total depends on region, uptime, usage, and current pricing. Older estimates in this project are only rough examples, not a quote.

- Start with a reviewed plan and the AWS Pricing Calculator.
- Avoid deploying staging or prod for a simple portfolio demo.
- To reduce spend, consider disabling RDS and/or NAT in a dev-only configuration, but understand the trade-offs: without NAT, private instances may not be able to download packages; the current nginx user-data script expects network access.
- If you do deploy, track every created resource and clean up deliberately after testing. Confirm the destroy plan carefully; the bootstrap state bucket has `prevent_destroy` enabled and must be handled separately.
- Do not run `terraform destroy` blindly in an environment containing data you need.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with an appropriately scoped IAM role/profile
- Access to create the resources in the chosen environment
- A globally unique S3 bucket name for the remote state backend

Never commit AWS access keys, passwords, state files, plan files, private keys, or real `*.tfvars` files.

## Usage on Ubuntu / Linux (Bash)

The steps below are a deployment guide, **not a claim that resources have been created**. Review every plan before applying it. You can run formatting and validation checks without applying infrastructure.

### 1. Validate the Terraform configuration without deploying

From the repository root:

```bash
terraform fmt -check -recursive
```

Validate each environment and bootstrap configuration:

```bash
cd bootstrap
terraform init -backend=false
terraform validate

cd ../environments/dev
terraform init -backend=false
terraform validate

cd ../staging
terraform init -backend=false
terraform validate

cd ../prod
terraform init -backend=false
terraform validate
```

These checks do not apply infrastructure. Backend-disabled initialization is intended for validation; it does not test connectivity to your configured remote backend.

### 2. Create the remote state backend (one-time AWS resource creation)

Only do this when you are ready to create AWS resources and have reviewed the cost/security implications. Choose a globally unique bucket name; do not use the placeholder literally.

```bash
cd ../../bootstrap
terraform init
terraform plan -var='state_bucket_name=REPLACE-WITH-YOUR-UNIQUE-BUCKET' -out=bootstrap.tfplan
```

Inspect the plan output and, only if it is correct, apply the saved plan:

```bash
terraform apply bootstrap.tfplan
```

The bootstrap creates an S3 bucket and DynamoDB lock table. Keep the bootstrap state file safe; do not commit it.

### 3. Configure remote state and an environment

From the repository root:

```bash
cd environments
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` and replace `YOUR-UNIQUE-STATE-BUCKET` with the bucket created in the previous step. Keep the table name and region consistent with your bootstrap configuration.

For a **dev** configuration:

```bash
cd dev
cp terraform.tfvars.example terraform.tfvars
```

Review and edit `terraform.tfvars`. The sample enables NAT and RDS, both of which can cost money.

Initialize, create a plan, and inspect it:

```bash
terraform init -backend-config=../backend.hcl
terraform plan -out=dev.tfplan
```

Only if you understand and approve every planned resource, create the infrastructure:

```bash
terraform apply dev.tfplan
```

To work with staging or prod, use the corresponding folder and its own `terraform.tfvars.example`. Do not deploy prod just to test this portfolio project.

### 4. Inspect and clean up

If an environment was deployed, inspect its outputs:

```bash
terraform output
```

When you are certain the environment is disposable, review the destroy plan first:

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
```

Only after confirming that no required data/resources will be removed:

```bash
terraform apply destroy.tfplan
```

This destroys only the resources managed by that environment's state. The bootstrap S3 bucket and lock table are separate resources; do not delete the state backend while environment state still depends on it.

## Key design decisions (interview talking points)

- **Reusable modules:** networking, IAM, load balancing, compute, and database resources are separated by responsibility.
- **Separate state per environment:** dev, staging, and prod use distinct S3 state keys.
- **State protection:** S3 versioning/encryption/public-access blocking and DynamoDB locking are configured in the bootstrap.
- **Layered security groups:** application traffic is allowed from the ALB security group; database traffic is restricted to the app security group.
- **Secrets handling:** RDS master credentials are managed by AWS Secrets Manager rather than hard-coded in Terraform.
- **No SSH keys for EC2:** the instance profile supports Systems Manager; IMDSv2 is required and EBS volumes are encrypted.
- **AMI lookup:** the latest Amazon Linux 2023 AMI is resolved using an AWS public SSM parameter.
- **Higher availability design in prod:** three AZs, NAT per AZ, Multi-AZ RDS, deletion protection, and longer backups.

## Current verification status

- Terraform formatting and validation checks were run previously for the bootstrap and environment configurations.
- No `terraform apply` was run as part of those checks, and this repository should not be described as deployed or production-tested.
- Ansible, TFLint, tfsec, and live AWS deployment testing have not been confirmed.

## Possible extensions

- HTTPS with ACM and Route 53
- CloudWatch alarms and dashboards
- CI checks for `terraform fmt`, `validate`, TFLint, and security scanning on pull requests
- Additional tests and documented cost estimates based on the AWS Pricing Calculator
