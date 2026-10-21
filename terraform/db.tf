resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow PostgreSQL 5432 only from App SG and SSH from trusted IP"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "PostgreSQL access strictly from App Security Group"
    from_port       = 5432 #postrgress def port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  ingress {
    description = "SSH access from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id #gets latest ubuntu ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_name
  tags = {
    Name = "${var.project_name}-db-host"
  }
}
resource "aws_ebs_volume" "db_data" {
  availability_zone = aws_instance.db.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "${var.project_name}-db-data-volume"
  }
}
resource "aws_volume_attachment" "db_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = aws_instance.db.id
}
