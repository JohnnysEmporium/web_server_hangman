output "instance_ip_addr" {
  value = aws_instance.app-server.public_ip
}