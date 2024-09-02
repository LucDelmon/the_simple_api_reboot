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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_instance_connect_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
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

resource "aws_security_group" "ec2_instance_connect_sg" {
  name        = "ec2_instance_connect_sg"
  description = "Security group for EC2 Instance Connect Endpoint"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.whitelist_ip}/32"] # Restrict to your IP for SSH access
  }

  ingress {
    from_port         = 3128
    to_port           = 3128
    protocol          = "tcp"
    cidr_blocks       = ["10.0.4.219/32"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "connect_to_app" {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.ec2_instance_connect_sg.id
  source_security_group_id = aws_security_group.app_server_security_group.id
}

data "aws_ec2_managed_prefix_list" "cloudfront_prefix_list" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_security_group" {
  name        = "alb_security_group"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront_prefix_list.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}
