resource "null_resource" "connect_workers_script" {
  depends_on = [virtualbox_vm.node[0]]

  provisioner "local-exec" {
    command = "scp -i ./user_data/vagrant -o StrictHostKeyChecking=no vagrant@${virtualbox_vm.node[0].network_adapter[0].ipv4_address}:/home/vagrant/connect_workers.sh ./user_data/connect_workers.sh"
  }
}

resource "null_resource" "copy_kubeconfig" {
  depends_on = [virtualbox_vm.node[0]]

  provisioner "local-exec" {
    command = "scp -i ./user_data/vagrant -o StrictHostKeyChecking=no vagrant@${virtualbox_vm.node[0].network_adapter[0].ipv4_address}:/home/vagrant/k3s-config.yaml ./user_data/k3s-config.yaml"
  }
}

output "node_ips" {
  value = { for idx, vm in virtualbox_vm.node :
    local.node_names[idx] => vm.network_adapter[0].ipv4_address
  }
}