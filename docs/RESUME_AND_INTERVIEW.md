# Resume bullets

**Terraform AWS Infrastructure as Code** | Terraform, AWS (VPC, EC2/ASG, ALB, RDS, IAM, S3, DynamoDB), Ansible, Git

- Designed and provisioned a multi-tier AWS architecture (VPC, public/private subnets, ALB, Auto Scaling EC2, encrypted RDS MySQL) using five reusable Terraform modules.
- Implemented remote state in S3 with versioning and DynamoDB locking, with one isolated state per environment (dev/staging/prod) from a single codebase driven by tfvars.
- Enforced security best practice: chained security groups (ALB -> app -> DB), SSM access instead of SSH, IMDSv2, encrypted EBS/RDS, and RDS passwords managed in Secrets Manager (no secrets in code or state).
- Built production HA settings (3 AZs, NAT per AZ, Multi-AZ RDS, deletion protection) while keeping dev on a low-cost footprint.
- Authored an Ansible playbook for post-provision hardening and documented architecture, cost and runbooks.

Add a metric once you have one, e.g. "Cut environment provisioning from ~half a day to under 15 minutes."

# Interview Q&A

**What is Terraform state and why remote?** It maps config to real resources. Remote state (S3) is shared, versioned and encrypted; DynamoDB locking stops concurrent applies.

**How do you manage multiple environments?** Same modules, one folder per environment with its own tfvars and state key. (Alternatives: workspaces, Terragrunt.) Folders were chosen so prod can diverge safely and has an isolated blast radius.

**Module vs resource?** A module is a reusable, parameterised group of resources with inputs/outputs.

**plan vs apply vs destroy?** plan previews the diff, apply executes it, destroy removes everything in state.

**How do you avoid secrets in Terraform?** `manage_master_user_password` for RDS, Secrets Manager/SSM Parameter Store, sensitive variables, encrypted remote state.

**What if someone changes a resource in the console?** Drift: `terraform plan` shows it; apply reverts it, or `terraform import`/`refresh` adopts it.

**State lock stuck?** Confirm nobody is running apply, then `terraform force-unlock <ID>`.

**Terraform vs Ansible?** Terraform provisions infrastructure (declarative); Ansible configures software on it.

**count vs for_each?** count is index-based (removing item 0 shifts the others); for_each is key-based and more stable.

**How would you add CI/CD?** PR runs fmt, validate, tflint, tfsec and plan (posted as a comment); merge to main applies to dev; prod apply needs manual approval.
