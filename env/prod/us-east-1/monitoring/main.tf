resource "aws_cloudwatch_metric_alarm" "rds_connection_alarm" {
  alarm_name          = "rds-database-connection-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alarm when RDS database connections drop to zero."
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  treat_missing_data = "breaching"
}

resource "aws_cloudwatch_event_rule" "rds_alarm_rule" {
  name = "rds-alarm-state-change-rule"

  event_pattern = file("${path.module}/event_pattern.json")
}

resource "aws_cloudwatch_event_target" "invoke_stepfn" {
  rule      = aws_cloudwatch_event_rule.rds_alarm_rule.name
  target_id = "trigger-stepfunction"
  arn       = var.step_functions_arn
  role_arn  = var.step_functions_role_arn
}
