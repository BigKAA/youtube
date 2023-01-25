#!/usr/bin/env bash

# Путь к директории, в которой находятся скрипты.
SKLEROZ="../1.26"

cd $SKLEROZ

# Базовые приложения
cd 01-base-app
kubectl create -f 00-priorityclass.yaml
kubectl -n kube-system create -f 01-nfs.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml

# Если нужно ставить helm
# wget https://get.helm.sh/helm-v3.10.0-linux-amd64.tar.gz
# tar -zxvf helm-v3.10.0-linux-amd64.tar.gz
# mv -f linux-amd64/helm /usr/local/bin/helm
# helm version
# helm list
# rm -rf helm-v3.10.0-linux-amd64.tar.gz linux-amd64

# Metallb
cd ../02-metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
sleep 45
kubectl -n metallb-system apply -f mlb.yaml

# Ingress controller
cd ../03-ingress-controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml -n ingress-nginx --create-namespace
