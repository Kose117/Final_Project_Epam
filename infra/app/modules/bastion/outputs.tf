output "instance_id" { value = aws_instance.bastion.id }
output "public_ip"   { value = aws_eip.this.public_ip }
output "sg_id"       { value = aws_security_group.bastion.id }
