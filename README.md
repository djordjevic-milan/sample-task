# sample-task

> [!NOTE]
> Deployment is tested on Ubuntu 24.04 LTS. Guide will follow setup on this OS. This setup will work fine on 16GB of RAM hardware.

For local deployment of k8s cluster and application first we need to setup environment.

## Prerequirements

1. Install Virtualbox https://www.virtualbox.org/wiki/Linux_Downloads

> [!TIP]
> Keep in mind that if you use virtual machine as running environment, you need to setup nested virtualisation.

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
cd sample-task
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

Before we run terraform apply, we have to set right permissions for private keys that are provided in `./user_data` directory. 
We will use default `vagrant` private key for terraform provisioners to access machines and instal k3s as well as ArgoCD. Also since `vagrant` key is publicly available and widely known, we will create new user "k3s" for accessing the nodes if necessary in the future.

```
chmod 600 ./user_data/vagrant ./user_data/k3s-user-key
```

> [!NOTE]
> Creation of k3s user is purly for demonstration purpose, since our repo is also public and key is already compromised. Anyway we can create our on key par with `ssh-keygen` command and provide it in `./user_data` dir.


Now we can run terraform apply:

```
# Lets check first with...
terraform plan
# We should se following plan: Plan: 7 to add, 0 to change, 0 to destroy.

# ...and apply
terraform apply

# type 'yes'
```

This can take a while depending on network speed, since we are downloading ubuntu focal image in line 4 `main.tf`.

After everything is done we sould get prepared cluster with ArgoCD deployed and output of nodes IP's. 

### Code explanation

> [!NOTE]
> For all provisioner conections we will use vagrant private key to access the nodes.

__Main.tf__

As we already mention `main.tf` will start downloading image for virtual machines and provision it. After VM's are started terraform provisioner will
first copy `/user_data/preinstall.sh` script to VM's. Then it will do the same for `./user_data/k3s-user-key.pub` key. Then in line 43 terraform provisioner will set the hostnames to VM's by reading values from list "node_names" form `locals.tf`. Then it will start `preinstall.sh` which will do the following:

0. Check for hostname of virtual machine and if equal "master.local", it will continue with the process.
1. Create k3s user, we mention already in this text
2. Install k3s cluster without flannel
3. Wait for 90s for cluster to be fully available
4. Taint master node so no pods will be schedule on it
5. Install calico which is mandatory for setting up network policies
6. Install ArgoCD
7. Create `connect_workers.sh` which will be exportet to `./user_data` directory and used bu null resource to connect nodes to master node.
8. Create kube config file which will be provided to `./user_data` directory we can later use to access cluster locally. It will prepare file by changing localhost address with IP address of master node, so we can use it immediately.

__connect_workers.tf__

`connect_workers.tf` create null resource dependent on "virtualbox_vm.node" and another null resource "connect_workers_script". This means that it will wait for all nodes to be ready and connect_workers_script to be created before starting. This provisioner will just run "connect_workers.sh" on worker nodes to connect 

### Troubleshooting

Known error during provisioning is:
```
Error: [ERROR] Clone *.vdi and *.vmdk to VM folder: exit status 1
```

This is most probobly specific to focal image that creates two disks which virtual box sometimes do not handel very well. 
https://github.com/terra-farm/terraform-provider-virtualbox/issues/33

> [!TIP]
> It's noticed that this is happening when Virtualbox application is opened. Keep app closed.

We can reapply terraform code and second time it should provision VM's as intended, but first we need to remove virtual machines from Virtualbox.

Its best to start from biginning and remove virtual machines from Virtualbox. Also remove configurations:

```
rm -rf ~/.config/VirtualBox
rm -rf ~/.terraform/virtualbox/
```

Also might be useful to drop cache for VM.
```
sudo su
echo 3 > /proc/sys/vm/drop_caches
```
