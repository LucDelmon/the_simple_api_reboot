terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.63.0"
    }

    github = {
      source  = "integrations/github"
      version = "6.2.2"
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

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "app_server" {
  ami           = "ami-07a0715df72e58928" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type, code is dependant to the region used
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_server_security_group.id]  # Associate the security group
  subnet_id              = aws_subnet.private[0].id  # Launch instance in private subnet
  private_ip             = "10.0.4.219"
  iam_instance_profile = aws_iam_instance_profile.ec2_role.name
  key_name      = aws_key_pair.deployer_key.key_name

  user_data = templatefile("${path.module}/ec2_user_data.sh", {
    DB_HOST      = aws_db_instance.my_database.address,
    DB_USERNAME  = var.db_username,
    WEB_CONCURRENCY = var.web_concurrency,
    REGION       = var.aws_region,
    SSH_PUBLIC_KEY = var.github_actions_public_key
  })

  depends_on = [aws_instance.bastion_host]

  tags = {
    Name = var.instance_name
  }
}

resource "aws_cloudwatch_log_group" "ec2_log_group" {
  name              = "/aws/ec2/${aws_instance.app_server.id}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "puma_stdout" {
  name           = "${aws_instance.app_server.id}/puma-stdout"
  log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
}

resource "aws_cloudwatch_log_stream" "puma_stderr" {
  name           = "${aws_instance.app_server.id}/puma-stderr"
  log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
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
  parameter_group_name = aws_db_parameter_group.postgresql_logging.name
  apply_immediately = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # multi_az = true
  # Enable Multi-AZ deployment for high availability
  # Deactivate this option if you are using a free tier account

  # Backup settings
  backup_retention_period = 7  # Keep backups for 7 days
  backup_window           = "02:00-03:00"  # Set a preferred backup window (UTC time)

  tags = {
    Name = "MyDatabase"
  }
}

resource "aws_db_parameter_group" "postgresql_logging" {
  name        = "postgresql-logging"
  family      = "postgres16"
  description = "Parameter group with enhanced logging for PostgreSQL."

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

  parameter {
    name  = "log_error_verbosity"
    value = "default"
  }

  parameter {
    name  = "log_min_error_statement"
    value = "error"
  }
}

resource "aws_cloudwatch_log_group" "rds_log_group" {
  name              = "/aws/rds/instance/${aws_db_instance.my_database.identifier}/general"
  retention_in_days = 7
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

  access_logs {
    bucket  = aws_s3_bucket.alb_logs_bucket.bucket
    enabled = true
  }

  drop_invalid_header_fields = true
  enable_deletion_protection = false
}

resource "aws_s3_bucket" "alb_logs_bucket" {
  bucket        = "my-alb-logs-bucket-simple-api"  # Name of the S3 bucket
  force_destroy = true  # Allows deletion of the bucket even if it contains objects

  tags = {
    Name = "ALBLogsBucket"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs_lifecycle" {
  bucket = aws_s3_bucket.alb_logs_bucket.bucket

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 10
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs_bucket_policy" {
  bucket = aws_s3_bucket.alb_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "AWS": "arn:aws:iam::897822967062:root"  # ELB account ID for eu-north-1 (Stockholm) see
          # see https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html#access-log-create-bucket
        },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.alb_logs_bucket.arn}/*"
      }
    ]
  })
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

resource "aws_cloudfront_distribution" "api_distribution" {
  origin {
    domain_name = var.alb_domain_name
    origin_id   = "ALBOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  aliases = [var.domain_name]

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""

  ordered_cache_behavior {
    path_pattern           = "/help"
    target_origin_id       = "ALBOrigin"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      headers      = ["Authorization"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 86400
  }

  default_cache_behavior {
    target_origin_id       = "ALBOrigin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.ssl_certificate_arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    bucket = aws_s3_bucket.cloudfront_logs_bucket.bucket_domain_name
    include_cookies = false
  }

  tags = {
    Name        = "APIDistribution"
    Environment = "Production"
  }
}

resource "aws_s3_bucket" "cloudfront_logs_bucket" {
  bucket        = "my-cloudfront-logs-bucket-simple-api"
  force_destroy = true  # Allows Terraform to destroy the bucket even if it contains objects

  tags = {
    Name        = "CloudFrontLogsBucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs_acl" {
  bucket = aws_s3_bucket.cloudfront_logs_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs_bucket_ownership" {
  bucket = aws_s3_bucket.cloudfront_logs_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_instance" "bastion_host" {
  ami           = "ami-090abff6ae1141d7d"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  private_ip = "10.0.1.252"
  user_data = <<-EOF
              #!/bin/bash
              echo "${var.github_actions_public_key}" >> /home/ec2-user/.ssh/authorized_keys
              yum update -y
              yum install -y squid
              sed -i '/http_access deny all/i acl my_network src 10.0.0.0/16\nhttp_access allow my_network' /etc/squid/squid.conf
              systemctl enable squid
              systemctl start squid
            EOF
}

resource "aws_eip" "bastion_eip" {
  domain = "vpc"
}

resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion_host.id
  allocation_id = aws_eip.bastion_eip.id
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

resource "aws_ssm_parameter" "region" {
  name  = "/simple_app/region"
  type  = "String"
  value = var.aws_region
}

resource "aws_ssm_parameter" "bastion_sg_id" {
  name  = "/simple_app/bastion_sg_id"
  type  = "String"
  value = aws_security_group.bastion.id
}

resource "aws_ssm_parameter" "bastion_host_ip" {
  name  = "/simple_app/bastion_host_ip"
  type  = "String"
  value = aws_instance.bastion_host.public_ip
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/simple_app/db_host"
  type  = "String"
  value = aws_db_instance.my_database.address
}
