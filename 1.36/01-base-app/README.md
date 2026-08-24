# Базовые приложения

Устанавливаем базовые вещи, которые понадобятся в будущем.

- **Helm** - установка Helm.
- **PriorityClass** - используются во всех манифестах.
- **csi-driver-nfs** - NFS CSI Driver для автоматизации создания PV и PVC.
- **cert-manager** - автоматическое создание сертификатов.
- **Metrics server** - метрики.
- **stakater reloader** - автоматическая перезагрузка подов при изменении ConfigMap и Secret.

## Helm

На контрол ноде или на машине с котрой вы будете управлять кластером установите Helm. Также лучше использовать актуальную версию [Helm](https://github.com/helm/helm/releases).

```shell
wget https://get.helm.sh/helm-v4.2.4-linux-amd64.tar.gz
tar -zxvf helm-v4.2.4-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/local/bin/helm
helm version
helm repo list
rm -rf helm-v4.2.4-linux-amd64.tar.gz linux-amd64
```

## PriorityClass

```sh
kubectl create -f 00-priorityclass.yaml
```

## NFS CSI Driver

Современный CSI-драйвер для NFS. Заменяет устаревший `nfs-subdir-external-provisioner`, который использует deprecated `Endpoints`.

В файле `01-nfs-csi-values.yaml` подставьте IP адрес вашего NFS сервера и путь к общей папке.

```sh
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
helm upgrade --install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --version v4.13.4 \
  -f 01-nfs-csi-values.yaml
```

Проверка установки:

```sh
kubectl -n kube-system get deployment/csi-nfs-controller
kubectl get storageclass
```

Документация: [kubernetes-csi/csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs)

## Cert manager

Будем использовать [helm chart](https://quay.io/repository/jetstack/charts/cert-manager). С дополнительными параметрами, необходимыми для работы с GatewayAPI.

Сначала поставим CRD GatewayAPI. Они необходимы для работы cert-manager.

```sh
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml"
```

```sh
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
```

**Важно!** Helm не обновляет CRD при `helm upgrade` (они применяются только при первой установке). Поэтому при обновлении существующей установки сначала примените CRD вручную:

```sh
kubectl apply --server-side --force-conflicts \
  -f "https://github.com/cert-manager/cert-manager/releases/download/v1.21.1/cert-manager.crds.yaml"
```

Поле `config.enableGatewayAPI` (использовалось до v1.21) объявлено устаревшим, вместо него — `config.gatewayAPI.enabled`.

Добавляем CA для всего кластера и ClusterIssuer. Я использую самоподписанный сертификат. Но потенциально можно пользоваться и Let's Encrypt.

В манифесте формируется `ClusterIssuer`: `dev-ca-issuer`, который будет использоваться в дальнейшем.

```shell
kubectl apply -f 02-certs.yaml
```

## Metrics server

Тут придётся делать небольшую "дырку" в безопасности кластера. Добавить при запуске приложения параметр `--kubelet-insecure-tls`. Поэтому я сначала сохраняю манифесты в файл, а потом применяю их.

Исходные манифесты можно скачать [тут](https://github.com/kubernetes-sigs/metrics-server/releases/) (актуальная версия — v0.9.0)

```sh
kubectl apply -f 03-metrics-server.yaml
```

Через некоторое время:

```shell
kubectl top node
```

## Reloader

[Полезная утилита](https://github.com/stakater/Reloader) для перезагрузки подов при изменении `ConfigMap` или `Secret`.

```sh
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
helm upgrade --install reloader stakater/reloader \
  --set=reloader.reloadStrategy=annotations \
  --version 2.2.16 \
  -n kube-system
```
