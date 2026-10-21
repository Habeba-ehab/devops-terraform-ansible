variable "region" {
  description = "AWS region where everything is created"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Name used in tags and resource names"
  type        = string
  default     = "devops-lab"
}

variable "my_ip" {
  description = "Your public IP in CIDR form (example: 1.2.3.4/32). Only this address can SSH in"
  type        = string
}

variable "key_name" {
  description = "Name of the key pair that will be created in AWS"
  type        = string
  default     = "devops-lab-key"
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/devops_lab.pub"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}
variable "vpc_cidr" {
  description = "IP range of the whole VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "IP range of the public subnet (must fit inside vpc_cidr)"
  type        = string
  default     = "10.0.1.0/24"
}
variable "root_volume_size" {
  description = "Size in GB of each instance's root disk"
  type        = number
  default     = 20
}