output "instance_id" { value = aws_instance.nat.id }
output "sg_id"       { value = aws_security_group.nat.id }
