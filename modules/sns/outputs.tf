output "sns_topic_arn" {
  value       = aws_sns_topic.this.arn
  description = "SNS topic ARN"
}