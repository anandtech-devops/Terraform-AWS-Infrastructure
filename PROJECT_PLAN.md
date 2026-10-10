# Project plan: Terraform AWS IaC

- [x] Bootstrap: S3 state bucket (versioned, encrypted, private) + DynamoDB lock table
- [x] Module: vpc (subnets, IGW, NAT single/per-AZ, routes)
- [x] Module: iam (EC2 role, SSM, instance profile)
- [x] Module: alb (ALB, target group, listener, SG)
- [x] Module: compute (launch template, ASG, SG, IMDSv2, encrypted EBS)
- [x] Module: rds (MySQL, SG, subnet group, managed password)
- [x] Environments: dev, staging, prod (tfvars + separate state keys)
- [x] Ansible playbook + dynamic inventory (optional)
- [x] README with architecture, cost warning, usage
- [x] Resume bullets + interview Q&A
- [x] terraform fmt + validate on all configs
- [ ] (Needs user approval, costs money) Real `plan`/`apply` against AWS
- [ ] (Extension) GitHub Actions pipeline, tflint/tfsec, HTTPS via ACM
