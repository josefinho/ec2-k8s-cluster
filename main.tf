
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "terraform-user"
}

resource "aws_instance" "master-node" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.medium"
  availability_zone = "us-east-1a"
  key_name = "k8s-cluster-key-pair"
  security_groups = [ "default", "master-node-sg" ]

  user_data = <<-USERDATA
    #!/bin/bash

    set -x

    echo "INFO: pre configuration for CRI (container runtime interface)"
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    sudo sysctl --system

    echo "INFO: Add Docker's official GPG key:"
    sudo apt-get update
    sudo apt-get -y install ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "INFO: Add the repository to Apt sources:"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    echo "INFO: install containerd"
    sudo apt-get -y install containerd.io

    echo "INFO: configure containerd"
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i s/SystemdCgroup\ =\ false/SystemdCgroup\ =\ true/g /etc/containerd/config.toml
    sudo systemctl restart containerd

    # installing kubeadm
    sudo swapoff -a

    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    sudo systemctl enable --now kubelet

    sudo kubeadm init

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

  USERDATA

  tags = {
    Name = "master-node"
    Application = "kubernetes"
    Node = "master"
  }
}

resource "aws_instance" "worker-node-1" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.large"
  availability_zone = "us-east-1a"
  key_name = "k8s-cluster-key-pair"
  security_groups = [ "default", "worker-node-sg" ]

  user_data = <<-USERDATA
    #!/bin/bash

    set -x

    echo "INFO: pre configuration for CRI (container runtime interface)"
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    sudo sysctl --system

    echo "INFO: Add Docker's official GPG key:"
    sudo apt-get update
    sudo apt-get -y install ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "INFO: Add the repository to Apt sources:"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    echo "INFO: install containerd"
    sudo apt-get -y install containerd.io

    echo "INFO: configure containerd"
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i s/SystemdCgroup\ =\ false/SystemdCgroup\ =\ true/g /etc/containerd/config.toml
    sudo systemctl restart containerd

    # installing kubeadm
    sudo swapoff -a

    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    sudo systemctl enable --now kubelet

  USERDATA



  tags = {
    Name = "worker-node-1"
    Application = "kubernetes"
    Node = "worker"
  }
}

# resource "aws_instance" "worker-node-2" {
#   ami           = "ami-0c7217cdde317cfec"
#   instance_type = "t2.large"
#   key_name = "k8s-cluster-key-pair"
#   security_groups = [ "default", "worker-node-sg" ]
#
#   tags = {
#     Name = "worker-node-1"
#     Application = "kubernetes"
#     Node = "worker"
#   }
# }
