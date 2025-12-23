# Базовые приложения

Устанавливаем базовые вещи, которые понадобятся в будущем.

- **Helm** - установка Helm.
- **PriorityClass** - используются во всех манифестах.
- **nfs-subdir-external-provisioner** - Для автоматизации создания PV и PVC.
- **cert-manager** - автоматическое создание сертификатов.
- **Metrics server** - метрики.
- **stakatter reloader** - автоматическая перезагрузка подов при изменении ConfigMap и Secret.

## Helm

На контрол ноде или на машине с котрой вы будете управлять кластером установите Helm. Также лучше использовать актуальную версию [Helm](https://github.com/helm/helm/releases).

```shell
wget https://get.helm.sh/helm-v4.0.4-linux-amd64.tar.gz
tar -zxvf helm-v4.0.4-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/local/bin/helm
helm version
helm repo list
rm -rf helm-v4.0.4-linux-amd64.tar.gz linux-amd64
```

## PriorityClass

```sh
kubectl create -f 00-priorityclass.yaml
```

## nfs-subdir-external-provisioner

В манифесте подставьте IP адрес вашего NFS сервера и путь к общей папке.

```sh
kubectl -n kube-system create -f 01-nfs.yaml
```

Проект достаточно старый. Использует в своей работе `Endpoints`, которые сейчас считаются устаревшими. При установке в новые кластера необходимо обратить внимание на это. Возможно его в дальнейшем автор обновить приложение, возможно нет.

## Cert manager

Будем использовать [helm chart](https://quay.io/repository/jetstack/charts/cert-manager). С дополнительными параметрами, необходимыми для работы с GatewayAPI.

Сначала поставим CRD GatewayAPI. Они необходимы для работы cert-manager.

```sh
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml"
```

```sh
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
```

Добавляем CA для всего кластера и ClusterIssuer. Я использую самоподписанный сертификат. Но потенциально можно пользоваться и Let's Encrypt.

В манифесте формируется `ClusterIssuer`: `dev-ca-issuer`, который будет использоваться в дальнейшем.

```shell
kubectl apply -f 02-certs.yaml
```

## Metrics server

Тут придется делать небольшую "дырку" в безопасности кластера. Добавить при запуске приложения параметр `--kubelet-insecure-tls`. Поэтому я сначала сохраняю манифесты в файл, а потом применяю их.

Исходные манифесты можно скачать [тут](https://github.com/kubernetes-sigs/metrics-server/releases/)

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
helm install reloader stakater/reloader --set=reloader.reloadStrategy=annotations -n kube-system
```
