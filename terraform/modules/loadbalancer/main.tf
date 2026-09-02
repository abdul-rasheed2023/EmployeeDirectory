# ==============================================================================
# LOAD BALANCER MODULE
# Application Load Balancer spanning both public subnets, its target group
# (the ASG registers instances into this), and the HTTP listener.
# ==============================================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.common_tags, { Name = "${var.project_name}-alb" })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/healthz/ready"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-app-tg" })
}

resource "aws_lb_listener" "http_external" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
