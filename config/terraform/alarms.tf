resource "aws_sns_topic" "my_sns_topic" {
  name = "my-sns-topic"

  tags = {
    Environment = "Production"
    Name        = "MySNSTopic"
  }
}

resource "aws_sns_topic_subscription" "my_subscription" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_cloudwatch_metric_alarm" "rds_backup_alarm" {
  alarm_name          = "RDSBackupFailureAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BackupRetentionPeriod"
  namespace           = "AWS/RDS"
  period              = "3600"
  statistic           = "Average"
  threshold           = "1"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.my_database.identifier
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "RDSHighCPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"  # Alarm when CPU utilization exceeds 80%

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.my_database.identifier
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_high_storage" {
  alarm_name          = "RDSHighStorageUtilization"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "536870912"  # Alarm when free storage is less than 0.5 GB

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.my_database.identifier
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name          = "HighCPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"  # Alarm when CPU utilization exceeds 80%

  dimensions = {
    InstanceId = aws_instance.app_server.id
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]
}

# next alarm can indicate that the instance is under-utilized, and you might consider resizing or terminating it.
# Since this is a test project, nobody is using the instance, so I let it commented

# resource "aws_cloudwatch_metric_alarm" "low_cpu_utilization" {
#   alarm_name          = "LowCPUUtilization"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "20"  # Alarm when CPU utilization is below 20%
#
#   dimensions = {
#     InstanceId = aws_instance.app_server.id
#   }
#
#   alarm_actions = [aws_sns_topic.my_sns_topic.arn]
#   ok_actions    = [aws_sns_topic.my_sns_topic.arn]
# }

resource "aws_cloudwatch_metric_alarm" "high_memory_usage" {
  alarm_name          = "HighMemoryUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"  # Alarm when memory usage exceeds 80%

  # The cloudwatch agent does not seems to send the metrics with dimensions when run as ubuntu
  # I am not debugging that since the cloudwatch agent look like a terrible tool. There are better tools for monitoring
  #   dimensions = {
  #     InstanceId = aws_instance.app_server.id
  #     ImageId      = aws_instance.app_server.ami
  #     InstanceType = aws_instance.app_server.instance_type
  #   }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]
}
