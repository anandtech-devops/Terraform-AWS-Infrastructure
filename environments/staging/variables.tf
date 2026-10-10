variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "tf-iac-demo"
}
variable "vpc_cidr" { type = string }
variable "az_count" {
  type    = number
  default = 2
}
variable "enable_nat_gateway" {
  type    = bool
  default = true
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}
variable "instance_type" { type = string }
variable "asg_min" { type = number }
variable "asg_max" { type = number }
variable "asg_desired" { type = number }
variable "enable_rds" {
  type    = bool
  default = true
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_multi_az" {
  type    = bool
  default = false
}
variable "db_backup_retention_days" {
  type    = number
  default = 1
}
variable "db_deletion_protection" {
  type    = bool
  default = false
}
