variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "App Server"
}

variable "aws_region" {
  description = "The AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "db_username" {
  description = "Username for the PostgreSQL database"
  type        = string
  default     = "rails"
}

variable "web_concurrency" {
  description = "Number of Puma worker processes"
  type        = number
  default     = 1
}

# Variable without a default value

variable "ssh_public_key" {
  description = "private SSH public key to use for the EC2 instance"
  type = string
}

variable "allowed_ip" {
  description = "The IP address to allow for SSH access"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name in the format username/repo."
  type        = string
}

variable "db_password" {
  description = "Password for the PostgreSQL database"
  type        = string
}

variable "terraform_admin_role_arn" {
  description = "ARN of the Terraform admin role"
  type        = string
}

variable "encryption_key_arn" {
  description = "ARN of the encryption key in Secrets Manager"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate in ACM"
  type        = string
}
