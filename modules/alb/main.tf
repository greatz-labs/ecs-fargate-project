data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "this" {}

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  https_enabled = var.certificate_arn != ""

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── ALB access log bucket ─────────────────────────────────────────────────────
# Receives one log entry per ALB request. Bucket name must be globally unique.

resource "aws_s3_bucket" "alb_logs" {
  # Account ID suffix ensures uniqueness without a random suffix
  bucket        = "${local.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lab — allows terraform destroy without manual bucket emptying

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-logs" })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Auto-expire logs after 90 days to control storage costs
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-alb-logs"
    status = "Enabled"

    filter {} # applies to all objects in the bucket

    expiration {
      days = 90
    }

    # Prevents incomplete multipart uploads from accumulating indefinitely
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ELB service account needs PutObject on the log prefix
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.this.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}

# ── ALB security group ────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB: allow inbound HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB must reach tasks on the container port
  egress {
    description = "Outbound to ECS tasks and AWS endpoints"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Application Load Balancer ─────────────────────────────────────────────────

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Prevent accidental deletion — remove this attribute before terraform destroy
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

# ── Target group ──────────────────────────────────────────────────────────────
# target_type = "ip" is required for Fargate awsvpc networking.
# Each task registers its own ENI IP directly.

resource "aws_lb_target_group" "blue" {
  name        = "${local.name_prefix}-blue-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    interval            = var.health_check_interval
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = 5
    matcher             = "200-299"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-blue-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${local.name_prefix}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    interval            = var.health_check_interval
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = 5
    matcher             = "200-299"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-green-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Counter target groups ─────────────────────────────────────────────────────
# Only created when create_counter = true. Both slots are always registered so
# ECS can validate the TG-to-ALB association at service creation time.

resource "aws_lb_target_group" "counter_blue" {
  count = var.create_counter ? 1 : 0

  # ecs-fargate-dev-counter-blue-tg = 31 chars (AWS limit: 32)
  name        = "${local.name_prefix}-counter-blue-tg"
  port        = var.counter_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.counter_health_check_path
    protocol            = "HTTP"
    interval            = var.health_check_interval
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = 5
    matcher             = "200-299"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-counter-blue-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "counter_green" {
  count = var.create_counter ? 1 : 0

  name        = "${local.name_prefix}-counter-green-tg"
  port        = var.counter_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.counter_health_check_path
    protocol            = "HTTP"
    interval            = var.health_check_interval
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = 5
    matcher             = "200-299"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-counter-green-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Path-based rule routes /counter and /counter/* to the counter slot TGs.
# Priority 10: evaluated before the banner default action; leaves headroom for future rules.
resource "aws_lb_listener_rule" "counter_https" {
  count = var.create_counter && local.https_enabled ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/counter", "/counter/*"]
    }
  }

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.counter_blue[0].arn
        weight = var.active_color == "blue" ? 100 : 0
      }
      target_group {
        arn    = aws_lb_target_group.counter_green[0].arn
        weight = var.active_color == "green" ? 100 : 0
      }
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-counter-https-rule" })
}

# ── Listeners ─────────────────────────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # If HTTPS is enabled, redirect everything. Otherwise forward directly.
  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https_enabled ? [] : [1]
    content {
      type = "forward"
      forward {
        target_group {
          arn    = aws_lb_target_group.blue.arn
          weight = var.active_color == "blue" ? 100 : 0
        }
        target_group {
          arn    = aws_lb_target_group.green.arn
          weight = var.active_color == "green" ? 100 : 0
        }
      }
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-listener-http" })
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = var.active_color == "blue" ? 100 : 0
      }
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = var.active_color == "green" ? 100 : 0
      }
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-listener-https" })
}
