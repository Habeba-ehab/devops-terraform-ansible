variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}
variable "my_ip" {
  description = "public IP for SSH access"
  type        = string
}
variable "key_name" {
  description = "AWS SSH key pair for EC2 access"
  type        = string
}
variable "instance_type" {
  description = "EC2 instance type "
  type        = string
  default     = "t2.micro"
}
