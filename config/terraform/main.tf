terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  cloud {
    organization = "Luc_Delmon"
    workspaces {
      name = "terraform-aws"
    }
  }
  required_version = ">= 1.2.0"
}

# see network.tf for the VPC, subnets, and route table configuration

# see security.tf for the security group configuration

# see variables.tf for the variable definitions

# This file contains the main configuration for instances

provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = var.terraform_admin_role_arn
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "app_server" {
  ami           = "ami-07a0715df72e58928" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type, code is dependant to the region used
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_server_security_group.id]  # Associate the security group
  key_name               = aws_key_pair.deployer.key_name  # Associate the key pair
  subnet_id              = aws_subnet.public[0].id  # Launch instance in public subnet
  iam_instance_profile = aws_iam_instance_profile.ec2_role.name


  user_data = templatefile("${path.module}/ec2_user_data.sh", {
    DB_HOST      = aws_db_instance.my_database.address,
    DB_USERNAME  = var.db_username,
    WEB_CONCURRENCY = var.web_concurrency,
    REGION       = var.aws_region,
    S3_BUCKET_URL = "s3://${aws_s3_bucket.deployments_bucket.bucket}"
  })

  tags = {
    Name = var.instance_name
  }
}

# Allocate an Elastic IP
resource "aws_eip" "app_server_eip" {
  vpc = true
}

resource "aws_eip_association" "app_server_eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.app_server_eip.id
}

resource "aws_iam_instance_profile" "ec2_role" {
  name = "ec2_role"
  role = aws_iam_role.ec2_role.name
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags = {
    Name = "MyDBSubnetGroup"
  }
}

resource "aws_db_instance" "my_database" {
  allocated_storage   = 5
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "16.3"
  instance_class      = "db.t3.micro"
  username            = var.db_username
  password            = var.db_password
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.allow_db_access.id]  # Allow access from the EC2 security group
  skip_final_snapshot = true
  db_name            = "the_simple_api_production"

  tags = {
    Name = "MyDatabase"
  }
}

resource "aws_s3_bucket" "deployments_bucket" {
  bucket = "simple-api-my-deployments-bucket"
  force_destroy = true

  tags = {
    Name        = "DeploymentsBucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.deployments_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [aws_iam_role.ec2_role.arn]
        },
        Action = "s3:GetObject",
        Resource = [
          "${aws_s3_bucket.deployments_bucket.arn}/*"
        ]
      }
    ]
  })
}

# application load balancer
# see internet.tf for the listener configuration
resource "aws_lb" "app_lb" {
  name               = "my-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app_target_group" {
  name     = "my-app-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/up"  # Replace with your health check endpoint
    interval            = 30
    timeout             = 5
    healthy_threshold  = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app_target" {
  target_group_arn = aws_lb_target_group.app_target_group.arn
  target_id        = aws_instance.app_server.id  # Your EC2 instance ID
  port             = 3000
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_ssm_parameter" "ec2_instance_id" {
  name  = "/simple_app/ec2_instance_id"
  type  = "String"
  value = aws_instance.app_server.id
}

resource "aws_ssm_parameter" "s3_bucket" {
  name  = "/simple_app/s3_bucket"
  type  = "String"
  value = aws_s3_bucket.deployments_bucket.bucket
}

resource "aws_ssm_parameter" "region" {
  name  = "/simple_app/region"
  type  = "String"
  value = var.aws_region
}
