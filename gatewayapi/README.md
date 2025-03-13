# Gateway API

[Документация](https://kubernetes.io/docs/concepts/services-networking/gateway/).

[Документация на сайте проекта](https://gateway-api.sigs.k8s.io/).

[Реализации контроллеров](https://gateway-api.sigs.k8s.io/implementations/).

## Traefik

[Документация](https://docs.traefik.io/).

```shell
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

В [чарте](manifests/01-application-treaefik.yaml) отключаем:

- функционал ingress контроллера;
- генерацию gateway по умолчанию;

Включаем провайдер kubernetesGateway. Он по умолчанию отключен. И настраиваем формат логов.

Для установки чарта использую ArgoCD:

```yaml
 kubectl apply -f manifests/01-application-treaefik.yaml
```

Обратите внимание на то, что в нашем случае чарт сам создаёт `GatewayClass` с именем `traefik`.

## Gateway

В дальнейшем работать будем в namespaces `sample`.

```shell
kubectl create ns sample
```

Готовим манифест Gateway.

### Listeners

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik-gateway
  namespace: sample
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      port: 8000
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 8443
      # hostaname для HTTPS и TLS listeners обязательно!
      hostname: sample.kryukov.local
      tls:
        mode: Terminate
        certificateRefs:
          - name: sample-tls
            namespace: sample
      allowedRoutes:
        namespaces:
          from: All
```

Обратите внимание на то, что значение `port` - это номер порта контейнера контроллера.
Номера портов берем из настроек самого traefik. Посмотреть какие entryPoints определены при запуске можно в манифесте пода.

```txt
--entryPoints.metrics.address=:9100/tcp
--entryPoints.traefik.address=:8080/tcp
--entryPoints.web.address=:8000/tcp
--entryPoints.websecure.address=:8443/tcp
```

__Пока непонятно, как при помощи cert-manager генерировать несколько сертификатов, для нескольких HTTPS listners.__

[`allowedRoutes`](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io%2fv1.AllowedRoutes) позволяет указывать namespaces, в которых можно использовать данный listener. Или kind, которые могут им пользоваться. _Имеются в виду HTTP/HTTPS и прочие routes из `gateway.networking.k8s.io/v1`_

### Интеграция Cert-manager

Cert-manager поддерживает `kind: Gateway`. Аннотации 100% совместимы с аннотациями для Ingress. Но! Чтобы cert-manager начал создавать сертификаты, его контроллер необходимо запустить с параметром `--enable-gateway-api`.

```yaml
  annotations:
    cert-manager.io/cluster-issuer: dev-ca-issuer
    cert-manager.io/common-name: sample.kryukov.local
    cert-manager.io/subject-organizations: "home dev lab"
    cert-manager.io/subject-countries: "RU"
    cert-manager.io/subject-localities: "Moscow"
    cert-manager.io/duration: "9125h"
    cert-manager.io/renew-before: "360h"
    cert-manager.io/usages: "server auth"
    cert-manager.io/private-key-algorithm: RSA
    cert-manager.io/private-key-encoding: "PKCS8"
    cert-manager.io/private-key-size: "4096"
    cert-manager.io/private-key-rotation-policy: Always
```

Добавляем Gateway в систему:

```shell
kubectl apply -f manifests/02-gateway.yaml
```

## Приложение пользователя

Воспользуемся [приложением](manifests/03-echo-app.yaml), которе приведено в качестве примера на сайте traefik.

```shell
kubectl apply -f manifests/03-echo-app.yaml
```

## HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: sample-http
  namespace: sample
spec:
  parentRefs:
    - name: traefik-gateway
      sectionName: web
      kind: Gateway
      # namespace: sample
  hostnames:
    - "sample.kryukov.local"
  rules:
    - backendRefs:
        - kind: Service
          name: whoami
          namespace: sample
          port: 80
      matches:
        - path:
            type: PathPrefix
            value: /
```

В `parentRefs` мы ссылаемся на `Gateway`, которы планируем использовать.

В `rules` описываем непосредственно маршрут пересылки.

Как видно из примера, Gateway и Service на которые мы ссылаемся, могут находиться в разных namespaces.

Применяем манифест:

```shell
kubectl apply -f manifests/04-http-route.yaml
```

Проверяем подключение.

## HTTP(S)Route

При использовании gateway listener HTTPS, при условии терминирования ssl на порту 443, мы тоже используем HTTPRoute.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: sample-https
  namespace: sample
spec:
  parentRefs:
    - name: traefik-gateway
      sectionName: https
      kind: Gateway
  hostnames:
    - "sample.kryukov.local"
  rules:
    - backendRefs:
        - kind: Service
          name: whoami
          namespace: sample
          port: 80
      matches:
        - path:
            type: PathPrefix
            value: /
```

Только в секции `parentRefs` ссылаемся уже на `https` listener.

```shell
kubectl apply -f manifests/05-https-route.yaml
```

## Дополнительные материалы

[Дополнительные материалы](update.md).
