resource "null_resource" "ipam_cleanup" {
  provisioner "local-exec" {
    when    = destroy # ← unquoted
    command = <<-EOT
      echo '{"allocated": {}, "subnet_allocations": {}}' > ipam_state.json
      echo '{}' >                                  ipam_output.json
    EOT
  }
}