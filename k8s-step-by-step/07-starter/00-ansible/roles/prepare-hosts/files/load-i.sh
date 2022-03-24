#!/usr/bin/env bash

for I in $(/root/docker-images/kubeadm-*-amd64 config images list); do
  echo ========================
  echo $I
  nerdctl pull $I
  ARCHIVE=$(echo $I | tr \/ _  | tr \: _ )
  nerdctl save $I -o $ARCHIVE.tar
  nerdctl rmi $I
done
# Кое что приходится фиксить руками для kubespray :(
nerdctl pull quay.io/coreos/etcd:v3.5.1
nerdctl save quay.io/coreos/etcd:v3.5.1 -o /root/k8s-images/quay.io_coreos_etcd_v3.5.1.tar
nerdctl rmi quay.io/coreos/etcd:v3.5.1

mv -f k8s.gcr.*.tar /root/k8s-images
