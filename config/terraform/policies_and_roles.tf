# policies

resource "aws_iam_policy" "secrets_manager_access" {
  name        = "secrets_manager_access"
  description = "Policy to allow EC2 instances to access Secrets Manager for the encryption key"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "secretsmanager:GetSecretValue",
        "Resource": var.encryption_key_arn,
        "Effect": "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_pull_policy" {
  name        = "S3PullPolicy"
  description = "Policy to allow write access to S3 for deployment"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.deployments_bucket.arn,
          "${aws_s3_bucket.deployments_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "s3_push_policy" {
  name        = "S3PushPolicy"
  description = "Policy to allow read access to S3 for deployment"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
        ]
        Resource = [
          aws_s3_bucket.deployments_bucket.arn,
          "${aws_s3_bucket.deployments_bucket.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_policy" "put_logs_policy" {
  name        = "PutLogsPolicy"
  description = "Policy for putting logs"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_send_policy" {
  name        = "SSMSendPolicy"
  description = "Policy for sending and checking ssm commands"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
        ],
        Resource = [
          aws_instance.app_server.arn,
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*",  # Allows access to all commands
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_receive_policy" {
  name        = "SSMReceivePolicy"
  description = "Policy for receiving ssm commands"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:UpdateInstanceInformation",
          "ssm:ListCommands",
          "ec2messages:GetMessages",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:SendReply",
          "ec2messages:DeleteMessage",
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_parameter_get_policy" {
  name        = "SSMParameterGetPolicy"
  description = "Policy to to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = [
          aws_ssm_parameter.region.arn,
          aws_ssm_parameter.bastion_host_ip.arn,
          aws_ssm_parameter.bastion_sg_id.arn,
          aws_ssm_parameter.db_host.arn,
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "edit_sg_policy" {
  name        = "EditGroupPolicy"
  description = "Policy to allow modifying security groups"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups"
        ],
        Effect   = "Allow",
        Resource = aws_security_group.bastion.arn
      }
    ]
  })
}



# create IAM roles

resource "aws_iam_role" "ec2_role" {
  name = "EC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# attach policies to roles

resource "aws_iam_role_policy_attachment" "attach_secrets_manager_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}
resource "aws_iam_role_policy_attachment" "attach_s3_pull_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_pull_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_ssm_send_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_receive_policy.arn
}
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_role_policy_attachment" "attach_put_logs_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.put_logs_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_s3_push_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.s3_push_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_ssm_receive_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.ssm_send_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_ssm_parameter_get_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.ssm_parameter_get_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_github_actions_sg_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.edit_sg_policy.arn
}
