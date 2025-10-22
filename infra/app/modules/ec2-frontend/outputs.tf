output "instance_id" { value = aws_instance.fe.id }
output "private_ip"  { value = aws_instance.fe.private_ip }
output "sg_id"       { value = aws_security_group.app.id }
