output "rds_alarm_rule_name" {
  value = aws_cloudwatch_event_rule.rds_alarm_rule.name
}
