data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Carve /24 subnets out of the VPC CIDR: public = .0, .1 ...  private = .10, .11 ...
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source               = "../../modules/vpc"
  name                 = local.name
  cidr_block           = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.tags
}

module "iam" {
  source = "../../modules/iam"
  name   = local.name
  tags   = local.tags
}

module "alb" {
  source            = "../../modules/alb"
  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  tags              = local.tags
}

module "compute" {
  source                = "../../modules/compute"
  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_sg_id             = module.alb.alb_sg_id
  target_group_arn      = module.alb.target_group_arn
  instance_profile_name = module.iam.instance_profile_name
  instance_type         = var.instance_type
  min_size              = var.asg_min
  max_size              = var.asg_max
  desired_capacity      = var.asg_desired
  tags                  = local.tags
}

module "rds" {
  count                 = var.enable_rds ? 1 : 0
  source                = "../../modules/rds"
  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  app_sg_id             = module.compute.app_sg_id
  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  tags                  = local.tags
}
