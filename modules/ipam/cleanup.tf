resource "null_resource" "ipam_cleanup" {
  triggers = {
    env      = var.environment
    vpc_name = var.vpc_name
    marker   = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo '{"resource_type":"reset","env":"${self.triggers.env}","vpc_name":"${self.triggers.vpc_name}"}' \
        | python3 ${path.module}/ipam_provider.py
    EOT
  }
}