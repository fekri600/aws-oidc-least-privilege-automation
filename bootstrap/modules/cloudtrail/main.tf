

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "ct-logs-${var.suffix}" 
}

# Bucket policy for CloudTrail + Access Analyzer read
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = templatefile("${path.module}/cloudtrail_bucket_policy.json", {
    aws_s3_bucket_cloudtrail_logs_arn = aws_s3_bucket.cloudtrail_logs.arn
    data_aws_caller_identity_current_account_id = var.account_id
    aws_iam_role_aa_policy_gen_role_arn = aws_iam_role.aa_policy_gen_role.arn
  })
}

# CloudTrail itself
resource "aws_cloudtrail" "main" {
  name                          = "org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  is_multi_region_trail         = true
  include_global_service_events = true
}

# NEW role for Access Analyzer to assume
resource "aws_iam_role" "aa_policy_gen_role" {
  name = "AccessAnalyzerPolicyGenRole"

  assume_role_policy = file("${path.module}/access_analyzer_assume_role_policy.json")
}

# Inline policy for that role
resource "aws_iam_role_policy" "aa_policy_gen_permissions" {
  name = "AccessAnalyzerPolicyGenPermissions"
  role = aws_iam_role.aa_policy_gen_role.name

  policy = templatefile("${path.module}/access_analyzer_role_policy.json", {
    aws_s3_bucket_cloudtrail_logs_arn = aws_s3_bucket.cloudtrail_logs.arn
  })
}
