resource "aws_sns_topic" "this" {
  name = "${var.name}-topic"
}

resource "aws_sns_topic_subscription" "email" {
  count = var.email_subscription != "" ? 1 : 0

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.email_subscription
}
