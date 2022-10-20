#! /bin/bash

BASED=$(pwd)

cd ../1.25/01-base-app/
kubectl create -f 00-priorityclass.yaml
kubectl -n kube-system create -f 01-nfs.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml

cd ../02-metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.5/config/manifests/metallb-native.yaml
echo "wait for metallb"
sleep 20
kubectl -n metallb-system apply -f mlb.yaml

cd ../03-ingress-controller
helm install ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml -n ingress-nginx --create-namespace
echo "wait for ingress controller"
sleep 15

cd $BASED
