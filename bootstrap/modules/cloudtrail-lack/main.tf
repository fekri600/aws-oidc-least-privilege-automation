resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_cloudtrail_event_data_store" "ci_lake" {
  name                        = "ci-least-priv-eds-${random_id.suffix.hex}"
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
  retention_period            = 30
}