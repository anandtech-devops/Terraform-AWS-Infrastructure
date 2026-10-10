terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket/region/table are supplied at init time: terraform init -backend-config=../backend.hcl
  backend "s3" {
    key     = "staging/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}
