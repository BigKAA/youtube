# Envoy Gateway

[Реализация Gateway API в Envoy](https://gateway.envoyproxy.io/).

## Установка

### Metallb

В моем тестовом стенде MetalLB не был до конца сконфигурирован. Поэтому добавим диапазон IP, которые он будет использовать в сервисах типа `LoadBalancer`:

```sh
kubectl apply -f manifest-envoy/mlb.yaml 
```

### Helm chart

В данном примере мы будем ставить envoy-gateway до того, как будет установлен ArgoCD. Перед установкой приложения в локальном кластере установлена и настроена реализация сервисов типа LoadBalancer: MetalLB.

[Helm charts envoyproxy/gateway-helm](https://hub.docker.com/r/envoyproxy/gateway-helm/tags).

Для ознакомления с чартом, его можно скачать локально:

```shell
helm pull oci://docker.io/envoyproxy/gateway-helm --version v1.3.1 --untar
```

В файле values ничего особенного вы не встретите. Поэтому ставим приложение по умолчанию:

```shell
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.3.1 -n envoy-gateway-system --create-namespace
```

### Тестовое приложение

Дя тестирования GatewayAPI будем использовать простейшее приложение.
Создадим для него namespace:

```shell
kubectl create ns sample
```

Запустим тестове приложение:

```shell
kubectl apply -f manifest-envoy/00-test-application.yaml
```

### Proxy Configuration

Для каждого `Gateway` будет создаваться отдельный экземпляр прокси envoy. Конфигурация прокси происходит при помощи `kind: EnvoyProxy`. Это особенность непосредственно envoy и никакого отношения к GatewayAPI не имеет.

Конфигурацию можно привязать к `GatewayClass`. Тогда она будет распространяться на все экземпляры envoy proxy, относящиеся к этому классу. Либо делать отдельную конфигурацию для каждого экземпляра `Gateway`. Т.е. для отдельного экземпляра envoy.

[API EnvoyProxy](https://gateway.envoyproxy.io/docs/api/extension_types/#envoyproxy).

Мне для отладки потребовалось изменить информацию, выдаваемую envoy в логи. И изменить параметр `externalTrafficPolicy` у создаваемых сервисов с `Local` на `Cluster`.

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: my-proxy-config
  namespace: sample
spec:
  logging:
    level: 
      default: warn
      upstream: info
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        externalTrafficPolicy: Cluster
        type: LoadBalancer
```

```shell
kubectl apply -f manifest-envoy/01-EnvoyProxy-Config.yaml
```

### GatewayClass

В `GatewayClass` подключаем конфигурацию `EnvoyProxy`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: my-proxy-config
    namespace: sample
```

Создаём GatewayClass:

```shell
kubectl apply -f manifest-envoy/02-gateway-class.yaml
```

Имя контроллера `gateway.envoyproxy.io/gatewayclass-controller` задается по умолчанию при установке приложения. Но его можно изменить в файле `values.yaml` чарта.

### Gateway

При создании `Gateway` мы добавим два `liteners`: `http` и `https`. Для работы последнего потребуются SSL сертификаты. Можно заранее создать сикрет с ними. Но мы будем пользоваться cert-manager, который будет автоматически создавать и поддерживать работу с сертификатами.

**Важно понимать**, что для работы cert-manager с GatewayAPI в кластере должны быть установлены CRD GatewayAPI! Поэтому установка cert-manager будет производиться строго после envoyproxy gateway, в состав которого эти CRD входят.

```shell
helm -n cert-manager install cert-manager jetstack/cert-manager \
  --set="extraArgs[0]=--enable-gateway-api" \
  --set="crds.enabled=true" \
  --create-namespace
```

Сразу добавим `Issuer`

```shell
kubectl apply -f manifest-envoy/certs.yaml
```

Добавляем Gateway:

```shell
kubectl apply -f manifest-envoy/03-gateway.yaml
```

Убеждаемся, что появился сервис типа `LoadBalancer` и под envoy proxy:

```shell
kubectl -n envoy-gateway-system get
```

### HTTPRoute

Добавляем два `HTTPRoute`, по одному для каждого `listener`:

```shell
kubectl apply -f manifest-envoy/04-http-route.yaml
kubectl apply -f manifest-envoy/05-https-route.yaml
```

Проверяем доступность нашего приложения через кластерный IP:

```shell
curl -H "Host: sample.kryukov.local" http://192.168.218.180
curl -kH "Host: sample.kryukov.local" https://192.168.218.180
```
