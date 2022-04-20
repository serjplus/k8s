#!/bin/bash
yum -y update
yum remove -y firewalld
yum -y install ntp nano net-tools wget curl mc sshpass iptables-services
systemctl enable ntpd
systemctl start ntpd

mkdir -p $HOME/.kube
mkdir /etc/cni
hostnamectl set-hostname k8s-masternode

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

ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
sshpass -p "root" ssh-copy-id -o StrictHostKeyChecking=no root@k8s-workernode1
sshpass -p "root" ssh-copy-id -o StrictHostKeyChecking=no root@k8s-workernode2

iptables -I INPUT -p tcp --dport 6443 -j ACCEPT
iptables -I INPUT -p tcp --dport 2379 -j ACCEPT
iptables -I INPUT -p tcp --dport 2380 -j ACCEPT
iptables -I INPUT -p tcp --dport 10250 -j ACCEPT
iptables -I INPUT -p tcp --dport 10251 -j ACCEPT
iptables -I INPUT -p tcp --dport 10252 -j ACCEPT
iptables -I INPUT -p tcp --dport 10255 -j ACCEPT
iptables -I INPUT -p tcp --dport 10256 -j ACCEPT
iptables -I INPUT -p tcp --dport 10248 -j ACCEPT
iptables -I INPUT -p tcp --dport 2381 -j ACCEPT
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -p tcp --dport 6784 -j ACCEPT
/usr/libexec/iptables/iptables.init save

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

kubeadm config images pull
cat <<EOF > /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.6 --cgroup-driver=cgroupfs"
EOF

wget -k https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml
mv recommended.yaml dashboard.yaml
kubectl --kubeconfig /etc/kubernetes/admin.conf create -f dashboard.yaml
kubectl create serviceaccount cluster-admin-dashboard-sa
kubectl create clusterrolebinding cluster-admin-dashboard-sa   --clusterrole=cluster-admin   --serviceaccount=default:cluster-admin-dashboard-sa
kubectl get secret | grep cluster-admin-dashboard-sa
kubectl describe secret cluster-admin-dashboard-sa-token-cmcz7
