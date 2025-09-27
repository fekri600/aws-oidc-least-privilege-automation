# Enable CloudTrail (if you don’t already have one)
resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name                = aws_s3_bucket.ct_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}

resource "aws_s3_bucket" "ct_logs" {
  bucket = "my-cloudtrail-logs-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_policy" "ct_policy" {
  bucket = aws_s3_bucket.ct_logs.id
  policy = templatefile("${path.module}/cloudtrail-s3-policy.json", {
    bucket_arn = aws_s3_bucket.ct_logs.arn
  })
}

# Enable IAM Access Analyzer at account level
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "account-analyzer"
  type          = "ACCOUNT"
}

# IAM role for Access Analyzer to assume when reading CloudTrail logs
resource "aws_iam_role" "access_analyzer_role" {
  name = "access-analyzer-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "access-analyzer.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Access Analyzer role to read CloudTrail logs
resource "aws_iam_role_policy" "access_analyzer_policy" {
  name = "aa-read-cloudtrail-inline"
  role = aws_iam_role.access_analyzer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- S3: read the CloudTrail log bucket ---
      {
        Effect   = "Allow"
        Action   = ["*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.ct_logs.arn}/*"
      },

      # --- CloudTrail: read-only (validate trail details you passed) ---
      {
        Effect = "Allow"
        Action = [
          "cloudtrail:GetTrail",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:GetEventSelectors",
          "cloudtrail:GetInsightSelectors"
        ]
        Resource = aws_cloudtrail.main.arn
      },
      {
        Effect   = "Allow"
        Action   = ["cloudtrail:DescribeTrails", "cloudtrail:ListTrails"]
        Resource = "*"
      }

      # If your trail uses SSE-KMS for S3 objects, also add:
      # ,{
      #   "Effect":"Allow",
      #   "Action":["kms:Decrypt"],
      #   "Resource": "<kms-key-arn>"
      # }
    ]
  })
}
