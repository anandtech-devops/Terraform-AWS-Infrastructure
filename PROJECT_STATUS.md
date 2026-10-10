# Project status

## Verified (command output seen)
- `terraform fmt -check -recursive`: passes (exit 0)
- `terraform init -backend=false` + `terraform validate`: **Success** for bootstrap, environments/dev, staging, prod (Terraform + AWS provider ~> 5.0)

## NOT verified
- No `plan` or `apply` was run (needs AWS credentials and creates billable resources; approval required).
- Ansible playbook not executed (ansible not installed locally).
- tflint / tfsec not run (not installed).

## Known notes
- Default region is ap-south-1; change `region` in tfvars/bootstrap if needed.
- Dev needs NAT enabled for nginx install via user data (about $33/month while running).

## Next steps
1. Run bootstrap, then `terraform plan` in environments/dev and review the output.
2. Apply only after reviewing the cost section in README.md; destroy after demo.
