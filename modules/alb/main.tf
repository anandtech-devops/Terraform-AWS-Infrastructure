variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "target_port" {
  type    = number
  default = 80
}
variable "health_check_path" {
  type    = string
  default = "/"
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Allow HTTP from the internet to the ALB"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb-sg" })
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name}-tg"
  port     = var.target_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_sg_id" { value = aws_security_group.alb.id }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
