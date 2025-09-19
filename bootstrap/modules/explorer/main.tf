
# Enable an LOCAL index in your home region
resource "aws_resourceexplorer2_index" "main" {
  type = "LOCAL"
}



# Create a default view (all resources)
resource "aws_resourceexplorer2_view" "all" {
  name = "all-resources"

  # Set this as the default view
  default_view = true

}
