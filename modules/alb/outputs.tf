output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB DNS name — use this for CNAME or Route53 alias records"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID — needed for Route53 alias records"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "Target group ARN — pass to ECS service load_balancer block"
  value       = aws_lb_target_group.this.arn
}

output "alb_security_group_id" {
  description = "ALB security group ID — ECS task SG should allow ingress from this"
  value       = aws_security_group.alb.id
}

output "http_listener_arn" {
  description = "HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN — null if no certificate_arn was provided"
  value       = try(aws_lb_listener.https[0].arn, null)
}
