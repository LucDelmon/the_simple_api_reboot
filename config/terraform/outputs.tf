output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "db_instance_endpoint" {
  description = "Endpoint of the RDS PostgreSQL instance"
  value       = aws_db_instance.my_database.endpoint
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
  description = "The DNS name of the ALB"
}

output "deployments_bucket_name" {
  value = aws_s3_bucket.deployments_bucket.bucket
  description = "The name of the S3 bucket used for deployments"
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
  description = "The ARN of the IAM role assumed by GitHub Actions"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.api_distribution.domain_name
  description = "The domain name of the CloudFront distribution"
}

output "bastion_public_ip" {
  value = aws_instance.bastion_host.public_ip
  description = "The public IP address of the bastion host"
}
