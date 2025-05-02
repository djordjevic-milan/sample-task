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
5. ArgoCD cli https://argo-cd.readthedocs.io/en/stable/cli_installation/

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

`connect_workers.tf` create null resource dependent on "virtualbox_vm.node" and another null resource "connect_workers_script". This means that it will wait for all nodes and "connect_workers_script" resouce to be ready before start with creation. This provisioner will just run "connect_workers.sh" on worker nodes to connect k8s workers to cluster.

__outputs.tf__

"connect_workers_script" null resource will copy "connect_workers.sh" and kube config to `./user_data` directory. Later on we can use kube configuration to access the cluster. "connect_workers.sh" will be used to connect worker nodes to cluster.

__If we don't have any other configuration__ we can simply copy kube config file to ~/.kube/config. __Otherwise it can overwrite existing configuration.__. In that case update your kube config with configuration new cluster. 

```
# If no existing configuration
cp ./user_data/k3s-config.yaml ~/.kube/config
```

Also it will output node IP's so we don't need to search for it later on.

__locals.tf__

Define node names with rule that master node must be at the first palce. Also it will declare worker index excluding master, which is in our case 2. By adding or removing the names in "node_names" list, we can determen number of nodes that will be provisioned. This is defined in line 3 of `main.tf`.

__providers.tf__

Use latest Virtualbox provider.

### Troubleshooting

Known error during provisioning is:
```
Error: [ERROR] Clone *.vdi and *.vmdk to VM folder: exit status 1
```

This is most probobly specific to focal image that creates two disks which virtual box sometimes dont' handle very well. 
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
## Application

For application we are using app from following repository https://github.com/madhurajayashanka/docker-mysql-nodejs-reactjs-app

This repo already provide us with Dockerfile's that are ready for build. Images for application are built manually with docker build command and pushed to github repo on this location. https://github.com/djordjevic-milan?tab=packages. Images are publicly available. Application is desined to run on localhost which will be important later on when we have to access backend. For that we will need to expose port 3000 on localhost. This was mentioned Prerequirements block, when we talk about Kubernetes client installation.

After k8s cluster is up we can check node status with `kubectl get nodes`

```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

node_ips = {
  "master" = "192.168.10.179"
  "worker1" = "192.168.10.178"
  "worker2" = "192.168.10.177"
}
milan@milan-port:~/Downloads/sample-task/terraform$ cp ./user_data/k3s-config.yaml ~/.kube/config
milan@milan-port:~/Downloads/sample-task/terraform$ k get nodes
NAME            STATUS   ROLES                  AGE     VERSION
master.local    Ready    control-plane,master   10m     v1.32.3+k3s1
worker1.local   Ready    <none>                 7m42s   v1.32.3+k3s1
worker2.local   Ready    <none>                 7m46s   v1.32.3+k3s1
```

Now we can expose port for accessing locally to ArgoCD:

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD on __localhost:8080__. 
Username: admin Password:`argocd admin initial-password -n argocd`

If you want, change password with: `argocd account update-password`

Now create pipeline in ArgoCD and sync. First deploy database and then backend and frontend. Order is not mandatory but it will keed everything clean. For first deployment use auto-create namespace option. ArgoCD manifest files can be found in `./argocd/app-k8s`.



## k8s

This directory contains kubernetes manifests for application and database deployment.