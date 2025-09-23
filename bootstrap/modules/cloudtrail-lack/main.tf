resource "aws_cloudtrail_event_data_store" "ci_lake" {
  name                        = "ci-least-priv-eds"
  advanced_event_selector {
    name = "MgmtEventsAllRegions"
    field_selector {
      field = "eventCategory"
      equals = ["Management"]
    }
  }
  multi_region_enabled        = true
  organization_enabled        = false
  termination_protection_enabled = false
  retention_period            = var.retention_days
}