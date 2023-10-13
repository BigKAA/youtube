# Склерозник по v1.26

[Kuberntes API reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.26/).

```shell
cd 01-base-app
kubectl create -f 00-priorityclass.yaml
kubectl -n kube-system create -f 01-nfs.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
kubectl apply -f metrics-server.yaml
cd ../02-metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
sleep 60
kubectl -n metallb-system apply -f mlb.yaml
cd ../03-ingress-controller
helm install ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml -n ingress-nginx --create-namespace
cd ../04-argocd
kubectl create namespace argocd
kubectl -n argocd create -f 01-argocd.yaml
kubectl -n argocd create -f 04-certs.yaml -f 05-ingress.yaml
```