#!/bin/bash
# Create k3s user
USER="k3s"

## Add user
useradd -m $USER
usermod -aG sudo $USER
echo "$USER ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

## Create ssh dir
mkdir -p /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
chown $USER:$USER /home/$USER/.ssh

## Add k3s pub key
cat /tmp/ubuntu-key.pub >> /home/$USER/.ssh/authorized_keys
chmod 600 /home/$USER/.ssh/authorized_keys
chown $USER:$USER /home/$USER/.ssh/authorized_keys

## Set ownership to k3s
chown -R $USER:$USER /home/$USER


# Install k3s on master node

HOSTNAME=$(hostname)

if [ "$HOSTNAME" = "master.local" ]; then
  echo "***[INFO] Hostname is master.local - proceeding with k3s server installation.***"

  # Install k3s
  curl -sfL https://get.k3s.io | sh -

  # Taint master node
  sleep 120
  sudo k3s kubectl taint nodes master.local node-role.kubernetes.io/control-plane=:NoSchedule

  # Define vars
  TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
  WORKER_SCRIPT="/home/vagrant/connect_workers.sh"
  IP_ADDRESS=$(hostname -I | awk '{print $1}')
  KUBE_CONFIG="/etc/rancher/k3s/k3s.yaml"
  KUBE_CONFIG_EXPORT="/home/vagrant/k3s-config.yaml"

  # Create connect_workers.sh to connect worker nodes via terraform
  echo "curl -sfL https://get.k3s.io | K3S_URL=https://$IP_ADDRESS:6443 K3S_TOKEN=$TOKEN sh -" > "$WORKER_SCRIPT"

  # Get kube config file
  sed "s|https://127.0.0.1:6443|https://$IP_ADDRESS:6443|g" "$KUBE_CONFIG" > "$KUBE_CONFIG_EXPORT"

else
  echo "***[INFO] Hostname is not master.local - skipping k3s installation.***"
fi
