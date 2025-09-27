output "cloudtrail_arn" {
  description = "The ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_name" {
  description = "The name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "access_analyzer_role_arn" {
  description = "The ARN of the IAM role for Access Analyzer"
  value       = aws_iam_role.access_analyzer_role.arn
}
