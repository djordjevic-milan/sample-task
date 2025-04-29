resource "null_resource" "connect_worker" {
  count = length(local.worker_indexes)

  depends_on = [
    virtualbox_vm.node,
    null_resource.connect_workers_script
  ]

  provisioner "file" {
    source      = "./user_data/connect_workers.sh"
    destination = "/tmp/connect_workers.sh"

    connection {
      type        = "ssh"
      user        = "vagrant"
      private_key = file("./user_data/vagrant")
      host        = virtualbox_vm.node[local.worker_indexes[count.index]].network_adapter[0].ipv4_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/connect_workers.sh",
      "bash /tmp/connect_workers.sh"
    ]

    connection {
      type        = "ssh"
      user        = "vagrant"
      private_key = file("./user_data/vagrant")
      host        = virtualbox_vm.node[local.worker_indexes[count.index]].network_adapter[0].ipv4_address
    }
  }
}
