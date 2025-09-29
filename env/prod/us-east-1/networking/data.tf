data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Select only the first 2 availability zones
  selected_azs = slice(data.aws_availability_zones.available.names, 0, 2)
}