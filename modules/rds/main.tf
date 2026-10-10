variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_sg_id" { type = string }
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "backup_retention_days" {
  type    = number
  default = 1
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "MySQL reachable only from app servers"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-db-sg" })
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.app_sg_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_db_instance" "this" {
  identifier             = "${var.name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = "admin"
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # AWS generates the password and stores it in Secrets Manager - nothing in code or state
  manage_master_user_password = true

  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_days
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name}-final" : null
  tags                      = var.tags
}

output "endpoint" { value = aws_db_instance.this.endpoint }
output "master_secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
