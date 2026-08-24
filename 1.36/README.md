# Набор базовых компонент для кластера kubernetes

Набор базовых компонент кластера kubernetes, которые я использую в своих тестовых средах.

В отличии от предыдущих версий, произошла замена ingress controller на gatewayAPI.

> **Внимание!** Начиная с этой версии StorageClass называется `nfs-storage` вместо `managed-nfs-storage`, как было в предыдущих версиях. Все манифесты в `1.36` ссылаются на новое имя. Уже созданные PVC это не затрагивает (`storageClassName` у них не изменится), но новые PVC будут работать только через `nfs-storage`.

Выполняем на первой контрол ноде.

```sh
cd 01-base-app

wget https://get.helm.sh/helm-v4.2.4-linux-amd64.tar.gz
tar -zxvf helm-v4.2.4-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/local/bin/helm
helm version
helm repo list
rm -rf helm-v4.2.4-linux-amd64.tar.gz linux-amd64

kubectl create -f 00-priorityclass.yaml

helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
helm upgrade --install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --version v4.13.4 \
  -f 01-nfs-csi-values.yaml

kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml"

helm upgrade --install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.1 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set global.priorityClassName=high-priority \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.gatewayAPI.enabled=true
kubectl apply -f 02-certs.yaml

kubectl apply -f 03-metrics-server.yaml
kubectl wait -n kube-system --for=condition=Ready pods  --selector "k8s-app=metrics-server"

helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
helm upgrade --install reloader stakater/reloader \
  --set=reloader.reloadStrategy=annotations \
  --version 2.2.16 \
  -n kube-system

cd ../02-metallb/
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.16.1/config/manifests/metallb-native.yaml
kubectl wait -n metallb-system --for=condition=Ready pods --selector "app=metallb"
kubectl -n metallb-system apply -f mlb.yaml

cd ../03-gatewayAPI/
kubectl apply --server-side --force-conflicts \
  -f https://github.com/envoyproxy/gateway/releases/download/v1.9.0/envoy-gateway-crds.yaml

helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.0 \
  --set deployment.priorityClassName=high-priority \
  --set deployment.replicas=1 \
  --set crds.enabled=false \
  -n envoy-gateway-system --create-namespace

kubectl wait -n envoy-gateway-system --for=condition=Ready pods --selector "app.kubernetes.io/instance=eg"

kubectl apply -f 01-EnvoyProxy-Config.yaml \
 -f 02-gateway-class.yaml \
 -f 03-gateway-cert.yaml \
 -f 04-gateway.yaml
```

Остальные приложения ставим на свой вкус. Я обычно добавляю в кластер: ArgoCD и PostgreSQL. Для этого есть соответствующие манифесты в директориях `04-argocd` и `06-postgresql`.

Мой проект по автоматизации установки кластера kubernetes при помощи ansible: [00-kube-ansible](https://github.com/BigKAA/00-kube-ansible).
