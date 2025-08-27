output "rds_alarm_rule_name" {
  value = aws_cloudwatch_event_rule.rds_alarm_rule.name
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.stepfn_log.name
}