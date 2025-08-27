resource "aws_sfn_state_machine" "this" {
  name       = var.name
  role_arn   = var.role_arn
  definition = var.state_machine_definition

  dynamic "logging_configuration" {
    for_each = var.enable_logging ? [1] : []
    content {
      level                  = var.logging_level
      include_execution_data = var.include_execution_data
      log_destination        = var.cloudwatch_log_group_name
    }
  }

  tags = var.tags
}
