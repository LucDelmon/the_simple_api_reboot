# This file contains the security group configuration for the EC2 instance, the RDS instance and the ALB

resource "aws_security_group" "app_server_security_group" {
  name        = "app_server_security_group"
  description = "Allow inbound ICMP (ping) and SSH traffic"
  vpc_id     = aws_vpc.main.id

  ingress {
    from_port   = -1  # ICMP protocol
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow ping from anywhere
  }

  ingress {
    from_port   = 22    # SSH port
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_ip}/32"]  # Allow SSH
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["13.48.4.200/30"]  # Allow SSH traffic from EC2 Instance Connect
  }

  ingress {
    from_port   = 3000  # Puma server port
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_security_group.id]  # Allow traffic from ALB security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_db_access" {
  name        = "allow_db_access"
  description = "Allow access to PostgreSQL from the EC2 instance"
  vpc_id     = aws_vpc.main.id

  ingress {
    from_port   = 5432  # PostgreSQL default port
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.app_server_security_group.id]  # Allow access from the EC2 security group
  }

  ingress {
    from_port   = -1  # ICMP protocol
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow ping from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_security_group" {
  name        = "alb_security_group"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}
