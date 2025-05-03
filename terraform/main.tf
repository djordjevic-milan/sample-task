resource "virtualbox_vm" "node" {
  count = length(local.node_names)
  name  = local.node_names[count.index]
  image = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-vagrant.box"
  # image     = "./images/focal-server-cloudimg-amd64-vagrant.box"
  cpus   = 2
  memory = "2.0 gib"

  network_adapter {
    type           = "bridged"
    host_interface = "wlp0s20f3" # Check for your network interface
  }

  #Copy preinstall script to node
  provisioner "file" {
    source      = "./user_data/preinstall.sh"
    destination = "/tmp/preinstall.sh"

    connection {
      type        = "ssh"
      user        = "vagrant"
      private_key = file("./user_data/vagrant")
      host        = self.network_adapter[0].ipv4_address
    }
  }

  # Copy ubuntu public key to node
  provisioner "file" {
    source      = "./user_data/k3s-user-key.pub"
    destination = "/tmp/k3s-user-key.pub"

    connection {
      type        = "ssh"
      user        = "vagrant"
      private_key = file("./user_data/vagrant")
      host        = self.network_adapter[0].ipv4_address
    }
  }

  # Set hostname
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${local.node_names[count.index]}.local"
    ]

    connection {
      type        = "ssh"
      user        = "vagrant"
      private_key = file("./user_data/vagrant")
      host        = self.network_adapter[0].ipv4_address
    }
  }

  # Run preinstall script
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/preinstall.sh",
      "sudo bash /tmp/preinstall.sh"
    ]

    connection {
      type        = "ssh"
      user        = "vagrant"
      private_key = file("./user_data/vagrant")
      host        = self.network_adapter[0].ipv4_address
    }
  }
}

