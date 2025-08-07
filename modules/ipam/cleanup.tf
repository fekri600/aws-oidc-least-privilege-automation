resource "null_resource" "ipam_cleanup" {
  provisioner "local-exec" {
    when    = destroy # ← unquoted
    command = <<-EOT
      echo '{"allocated": {}, "subnet_allocations": {}}' > ipam/ipam_state.json
      echo '{}' >                                  ipam/ipam_output.json
    EOT
  }
}