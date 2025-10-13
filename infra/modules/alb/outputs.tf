output "alb_arn"               { value = aws_lb.this.arn }
output "alb_dns_name"          { value = aws_lb.this.dns_name }
output "alb_sg_id"             { value = aws_security_group.alb.id }
output "tg_frontend_arn"       { value = aws_lb_target_group.frontend.arn }
output "tg_backend_arn"        { value = aws_lb_target_group.backend.arn }
output "alb_arn_suffix"        { value = aws_lb.this.arn_suffix }  # ← AGREGAR
output "tg_frontend_arn_suffix"{ value = aws_lb_target_group.frontend.arn_suffix }  # ← AGREGAR
output "tg_backend_arn_suffix" { value = aws_lb_target_group.backend.arn_suffix }   # ← AGREGAR