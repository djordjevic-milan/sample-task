# sample-task

For local deployment of k8s cluster and application first we need to setup environment.

## Prerequirements

> [!NOTE]
> Deployment is tested on Ubuntu 24.04 LTS. Guide will follow setup on this OS.

1. Install Virtualbox https://www.virtualbox.org/wiki/Linux_Downloads

> [!TIP]
> Keep in mind that if you use VM for as an environment, you need to setup nested virtualisation.

2. Install Terraform:
```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update

sudo apt-get install terraform
```
3. Install Kubernetes client https://ubuntu.com/kubernetes/install. Even though we will use ArgoCD for deployment we still need kubectl later on for port forwarding and easier troubleshooting.
4. Install Git https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

We should be ready now. Let's start!

## Infrastructure - Terraform

Clone repository to your local machine

```
git clone https://github.com/djordjevic-milan/sample-task.git
```

Go to terrafrom directory and run terraform init

```
cd terraform
terraform init
```

After initialisation open `main.tf`. In line 11 `host_interface="wlp0s20f3"` change to your active network adapter. You can do this with following command:

```
ip link show up
```
Example output:
```
milan@milan-port:~/Documents/sample-task$ ip link show up
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
3: wlp0s20f3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DORMANT group default qlen 1000
.....
```
From example we can see that my active network adapter is wireless card `wlp0s20f3`. This means that we will run the VM's on the same network as local machine.

Now we can start with terraform apply

```
# Lets check first with...
terraform plan
# We should se following plan: Plan: 7 to add, 0 to change, 0 to destroy.

# ...and apply
terraform apply

# type 'yes'
```

This can a while depending on network speed, since we are downloading ubuntu focal image in line 4 `main.tf`.

After everything is done we sould get prepared cluster with ArgoCD deployed and output of nodes IP's. 

### Code explanation

As we already mention `main.tf` will start downloading image for virtual machines and provision it. After VM's are started terraform provisioner will
first copy `./user_data/k3s-user-key.pub` key to local machines