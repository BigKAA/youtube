# Быстрая установка базовых компонент

[Kuberntes API reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/).

```shell
cd 01-base-app
kubectl create -f 00-priorityclass.yaml
kubectl -n kube-system create -f 01-nfs.yaml
kubectl apply -f kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.2/cert-manager.yaml
kubectl apply -f metrics-server.yaml
sleep 30
kubectl apply -f 02-certs.yaml
kubectl top node
cd ../02-metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
sleep 60
kubectl -n metallb-system apply -f mlb.yaml
cd ../03-ingress-controller
helm install ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml -n ingress-nginx --create-namespace
cd ../04-argocd
kubectl create namespace argocd
helm install argocd argocd/argo-cd -f argo-values.yaml -n argocd
```
