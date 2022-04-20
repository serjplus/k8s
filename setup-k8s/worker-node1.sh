#!/bin/bash
yum -y update
yum remove firewalld
yum -y install ntp nano net-tools wget curl mc iptables-services
systemctl enable ntpd
systemctl start ntpd

hostnamectl set-hostname k8s-workernode1
exec bash
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

#  Master Node prepare and  install ######################
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

sed -i '/swap/d' /etc/fstab
swapoff -a

cat <<EOF > /etc/hosts
127.0.0.1 localhost
192.168.100.101 k8s-masternode node1
192.168.100.102 k8s-workernode1 node2
192.168.100.103 k8s-workernode2 node3
EOF

# Run this part on each server for Centos  ####################################
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum -y install docker kubelet kubeadm kubectl kubernetes-cni
systemctl enable docker
systemctl start docker
systemctl enable kubelet
systemctl start kubelet
