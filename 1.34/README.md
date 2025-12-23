# Набор базовых компонент для кластера kubernetes

Набор базовых компонент кластера kubernetes, которые я использую в своих тестовых средах.

В отличии от предыдущих версий, произошла замена ingress controller на gatewayAPI.

Выполняем на первой контрол ноде.

```sh
cd 01-base-app

wget https://get.helm.sh/helm-v4.0.4-linux-amd64.tar.gz
tar -zxvf helm-v4.0.4-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/local/bin/helm
helm version
helm repo list
rm -rf helm-v4.0.4-linux-amd64.tar.gz linux-amd64

kubectl create -f 00-priorityclass.yaml
kubectl -n kube-system create -f 01-nfs.yaml

helm upgrade --install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set global.priorityClassName=high-priority \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true
kubectl apply -f 02-certs.yaml

kubectl apply -f 03-metrics-server.yaml
kubectl wait -n kube-system --for=condition=Ready pods  --selector "k8s-app=metrics-server"

helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
helm install reloader stakater/reloader --set=reloader.reloadStrategy=annotations -n kube-system

cd ../02-metallb/
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
kubectl wait -n metallb-system --for=condition=Ready pods --selector "app=metallb"
kubectl -n metallb-system apply -f mlb.yaml

cd ../03-gatewayAPI/
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.6.1 \
  --set deployment.priorityClassName=high-priority \
  --set deployment.replicas=1 \
  --skip-crds \
  -n envoy-gateway-system --create-namespace
  
kubectl wait -n envoy-gateway-system --for=condition=Ready pods --selector "app.kubernetes.io/instance=eg"

kubectl apply -f 01-EnvoyProxy-Config.yaml \
 -f 02-gateway-class.yaml \
 -f 03-gateway-cert.yaml \
 -f 04-gateway.yaml
```

Остальные приложения ставим на свой вкус. Я обычно добавляю в кластер: ArgoCD и PostgreSQL. Для этого есть соответствующие манифесты в директориях `04-argocd` и `05-postgresql`.
