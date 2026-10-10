output "alb_url" {
  value = "http://${module.alb.alb_dns_name}"
}
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "db_endpoint" {
  value = var.enable_rds ? module.rds[0].endpoint : null
}
output "db_secret_arn" {
  description = "Secrets Manager ARN holding the generated DB password"
  value       = var.enable_rds ? module.rds[0].master_secret_arn : null
}
