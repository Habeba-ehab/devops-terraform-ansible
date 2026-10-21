output "app_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.app.public_ip
}
output "app_private_ip" {
  description = "EC2 instance private ip"
  value       = aws_instance.app.private_ip
}
output "db_public_ip" {
  description = "database EC2 instance public ip"
  value       = aws_instance.db.public_ip
}
output "db_private_ip" {
  description = "database EC2 instance private IP"
  value       = aws_instance.db.private_ip
}
