resource "aws_sfn_state_machine" "this" {
  name     = var.name
  role_arn = var.role_arn

  definition = templatefile("${path.module}/state_machine.json", {
    sns_topic_arn       = var.sns_topic_arn
    lambda_failover_arn = var.lambda_failover_arn
  })
}
