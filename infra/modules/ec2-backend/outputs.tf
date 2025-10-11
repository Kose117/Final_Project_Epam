output "instance_id" { value = aws_instance.be.id }
output "private_ip"  { value = aws_instance.be.private_ip }
output "sg_id"       { value = aws_security_group.app.id }
