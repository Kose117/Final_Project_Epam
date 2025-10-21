output "alb_arn"                { value = aws_lb.this.arn }
output "alb_dns_name"           { value = aws_lb.this.dns_name }
output "alb_sg_id"              { value = aws_security_group.alb.id }
output "tg_frontend_arn"        { value = aws_lb_target_group.frontend.arn }
output "tg_backend_arn" {
  value = try(aws_lb_target_group.backend[0].arn, null)
}

output "alb_arn_suffix"         { value = aws_lb.this.arn_suffix }
output "tg_frontend_arn_suffix" { value = aws_lb_target_group.frontend.arn_suffix }
output "tg_backend_arn_suffix" {
  value = try(aws_lb_target_group.backend[0].arn_suffix, null)
}