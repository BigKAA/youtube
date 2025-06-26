# Install Istio

- [Install Istio](#install-istio)
  - [Необходимые компоненты](#необходимые-компоненты)
  - [Тестовое приложение](#тестовое-приложение)
  - [Установка Istio](#установка-istio)
    - [Chart ambient](#chart-ambient)
  - [Доступ к приложению пользователя](#доступ-к-приложению-пользователя)

## Необходимые компоненты

Для тестов я использую кластер kubernetes, установленный при помощи kubeadm ([ansible плейбук тут](https://github.com/BigKAA/00-kube-ansible)).

В кластере установлен [минимальный набор приложений](https://github.com/BigKAA/youtube/tree/master/1.31) из директорий 01* и 02*.

Вы можете использовать свой набор компонентов. Но в кластере обязательно должны работать сервисы типа `LoadBalancer`. Сервисы этого типа в дальнейшем будут использоваться в примерах.

## Тестовое приложение

Перед установкой Istio поставим тестовое приложение [BookInfo](https://istio.io/latest/docs/examples/bookinfo), которое разработчики Istio любезно предоставили для тестовых целей.

```shell
kubectl apply -f bookinfo/bookinfo.yaml
```

Как мы в дальнейшем убедимся, Istio можно внедрять по мере необходимости без остановки работы текущих приложений пользователей.

Приложение запущено, но мы пок ане имеем к нему доступа из-за пределов кластера. Вывести приложение можно при помощи сервисов типа NodePort.

## Установка Istio

Ставить Istio будем при помощи helm chart.

```shell
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

В первую очередь устанавливаем чарт, содержащий базовые компоненты. Такие как: CRD, ClusterRoles, Validating webhook.

```shell
helm install istio-base istio/base -n istio-system --create-namespace --wait
```

Следующим ставим CRD GatewayAPI. Прокси сервер Envoy, который будет реализовывать функционал GatewayAPI будет установлен позднее, как компонент Istio.

```shell
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

Теперь istio control plane. Сразу указываем, что будет использоваться режим ambient.

```shell
helm install istiod istio/istiod --namespace istio-system \
  --set profile=ambient --set global.logAsJson=true --wait 
```

CNI node agent.

```shell
helm install istio-cni istio/cni -n istio-system \
  --set profile=ambient --set global.logAsJson=true --wait
```

Установим data plane:

* ztunnel

```shell
helm install ztunnel istio/ztunnel -n istio-system \
  --set logAsJson=true --wait
```

* Ingress controller (опционально)

**Важно!** У меня в кластере установлен Metallb, отвечающий за сервисы типа LoadBalancer. По умолчанию Ingress controller будет использовать этот тип сервиса.


```shell
helm install istio-ingress istio/gateway -n istio-ingress --create-namespace
```

Смотрим, какой IP адрес получил сервис istio-ingress:

```shell
kubectl -n istio-ingress get svc
```

* GatewayAPI

Функционал GatewayAPI уже включен в Istio. Реализован на базе прокси сервера Envoy. Важно понимать, что эта реализация отличается от проекта Envoy Gateway.

### Chart ambient

В случае, когда мы устанавливаем Istio в режиме ambient, можно воспользоваться чартом "оберткой":

```shell
helm install istio istio/ambient -n istio-system
```

Он включает в себя чарты: `base`, `cni`, `istiod` и `ztunnel`. Имеет простейший файл values:

```yaml
global:
  variant: distroless

# Overrides for the `istiod-remote` dep
istiod:
  enabled: true
  profile: ambient

# Overrides for the `ztunnel` dep
ztunnel:
  profile: ambient
  resourceName: ztunnel

# Overrides for the `cni` dep
cni:
  profile: ambient
```

## Доступ к приложению пользователя

У нас уже установлено приложение в namespace default. После установки базовых компонент istio мы можем получить доступ к приложению. Несмотря на то, что мы установили Ingress controller, будем пользоваться функционалом GatewayAPI. Поскольку в istio планирует полностью перейти на него.

```shell
kubectl apply -f manifests/00-gateway-bookinfo.yaml
```

Традиционно для GatewayAPI запускается отдельный экземпляр Envoy.

```shell
kubectl get pods | grep ^book
```

И сервис типа LoadBalancer. Посмотрим, какой IP получил сервис:

```shell
kubectl get svc | grep ^book
```

Постучимся в наше приложение:

```shell
curl -v 192.168.218.181
```
