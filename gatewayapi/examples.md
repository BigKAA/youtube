# Дополнительные возможности GatewayAPI

- [Дополнительные возможности GatewayAPI](#дополнительные-возможности-gatewayapi)
  - [Подготовка поляны для экспериментов](#подготовка-поляны-для-экспериментов)
    - [Тестовое приложение](#тестовое-приложение)
    - [GatewayClass](#gatewayclass)
    - [SSL сертификат](#ssl-сертификат)
    - [Gateway](#gateway)
  - [Redirect](#redirect)
    - [HTTP to HTTPS](#http-to-https)
    - [Path redirect](#path-redirect)
  - [Rewrites](#rewrites)
  - [HTTP Header Modifiers](#http-header-modifiers)
  - [HTTP traffic splitting](#http-traffic-splitting)
    - [Canary](#canary)
    - [Blue-green](#blue-green)

Классический `Ingress` не имеет встроенных возможностей для дополнительной обработки запросов. Например пересылки по условию, Blue|green или метод "Канарейки" (canary). И некоторых других. Обычно управление расширениями реализуются при помощи аннотаций, не совместимых между различными реализациями ingress controllers. Например, [аннотации nginx ingress controller](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/).

В  GatewayAPI, по сравнению с Ingress, предоставляет расширенный набор возможностей, включенных непосредственно в API.

## Подготовка поляны для экспериментов

### Тестовое приложение

[Тестовое приложение](examples/00-test-applications.yaml) состоит из двух Deployments одного и того-же приложения но разных версий: `v0.0.1` и `v0.0.2`. 
Версия `v0.0.1` - текущая версия на продуктовом контуре. `v0.0.2` - новая версия от разработчиков. Приложения размещаются в namespace sample.

```shell
kubectl apply -f examples/00-test-applications.yaml
```

```shell
kubectl -n sample get svc
```

```txt
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
testapp-one   ClusterIP   10.233.40.161   <none>        80/TCP    9d
testapp-two   ClusterIP   10.233.11.88    <none>        80/TCP    9d
```

### GatewayClass

Предполагается, что приложение, реализующей GatewayAPI уже запущено. Создаём отдельный `GatewayClass`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: production
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
```

```shell
kubectl apply -f examples/01-gatewayclass.yaml
```

### SSL сертификат

Выпустим SSL сертификат для приложения. Вспоминаем, что не все реализации контроллера GatewayAPI правильно интерпретируют `kind: Gateway`, поэтому могут возникнуть проблемы с генерацией Secret при помощи cert-manager. Поэтому создаем отдельный манифест для сертификата.

```shell
kubectl apply -f examples/02-certificate.yaml
```

### Gateway

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: testapp-gw
  namespace: sample
spec:
  gatewayClassName: production
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: testapp-tls
            namespace: sample
      allowedRoutes:
        namespaces:
          from: Same
```

```shell
kubectl apply -f examples/03-gateway.yaml
```

## Redirect

Перенаправления возвращают клиенту ответы HTTP 3XX, указывая ему на необходимость получить другой ресурс.

### HTTP to HTTPS

Пример решения при помощи Ingress на базе nginx:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: testapp
  namespace: sample
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: testapp.kryukov.local
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
           name: testapp-one
           port:
             name: http
  tls:
  - hosts:
    - testapp.kryukov.local
    secretName: testapp-tls
```

Если использовать другой ingress controller, то аннотации будут другими. Например вот такие:

```yaml
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-2:***:certificate/****
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/group: testapp
```

Т.е. всё зависит от типа используемого Ingress контроллера.

Аналогичный redirect средствами GatawayAPI не зависит от типа используемого контроллера.

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: testapp-http-route
  namespace: sample
spec:
  parentRefs:
  - name: testapp-gw
    sectionName: http
  hostnames:
  - testapp.kryukov.local
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: testapp-https-route
  namespace: sample
spec:
  parentRefs:
  - name: testapp-gw
    sectionName: https
  hostnames:
  - testapp.kryukov.local
  rules:
  - backendRefs:
    - name: testapp-one
      port: 80
```

```shell
kubectl apply -f examples/04-http-https-route.yaml
```

Проверяем работу пересылки:

```shell
curl -vLk http://testapp.kryukov.local
```

### Path redirect

Добавим правила redirect:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: testapp-login-to-auth
  namespace: sample
spec:
  parentRefs:
  - name: testapp-gw
    sectionName: https
  hostnames:
  - testapp.kryukov.local
  rules:
  - matches:
      - path:
          type: PathPrefix
          value: /login
    filters:
      - type: RequestRedirect
        requestRedirect:
          path:
            type: ReplaceFullPath
            replaceFullPath: /auth
          statusCode: 302
```

Соответствие HTTPRoute сервису задаётся в `testapp-https-route`. Немного странно и не логично, но работает.

```shell
kubectl apply -f examples/05-path-redirect.yaml
```

Пошлем запрос:

```shell
curl -vLk https://testapp.kryukov.local/login
```

## Rewrites

Rewrites изменяют компоненты запроса клиента перед его проксированием. Фильтр URL-перезаписи может изменить имя хоста и/или путь запроса.

Удалим предыдущие HTTPRoutes:

```shell
kubectl delete -f examples/05-path-redirect.yaml
```

Добавим дополнительный `HTTPRoute` с правилом `URLRewrite`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: testapp-rewrite
  namespace: sample
spec:
  parentRefs:
  - name: testapp-gw
    sectionName: https
  hostnames:
  - testapp.kryukov.local
  rules:
  - matches:
      - path:
          type: PathPrefix
          value: /login
    filters:
      - type: URLRewrite
        urlRewrite:
          # hostname: anotherapp.kryukov.local
          path:
            # type: ReplaceFullPath
            type: ReplacePrefixMatch
            replacePrefixMatch: /auth
    backendRefs:
      - name: testapp-one
        port: 80
```

Я закоментировал пример изменения hostame. И вариант замены всего пути.

```shell
kubectl apply -f examples/06-rewrite.yaml
```

Пошлем запрос:

```shell
curl -vLk https://testapp.kryukov.local/login/22/12
```

Удалим HTTPRoutes:

```shell
kubectl delete -f examples/06-rewrite.yaml
```

## HTTP Header Modifiers

Доступна модификация и|или удаление заголовков в HTTP запросах и ответах.

Добавим секцию `filters` в `HTTPRoute`:

```yaml
    filters:
      - type: RequestHeaderModifier
        requestHeaderModifier:
          add:
            - name: Request-Test-Header
              value: "Request test value"
          remove:
            - "X-Envoy-External-Address"
      - type: ResponseHeaderModifier
        responseHeaderModifier:
          add:
          - name: Response-Test-Header
            value: "Response test value"
```

```shell
kubectl apply -f examples/07-header-modifiers.yaml
```

Пошлем запрос:

```shell
curl -vLk https://testapp.kryukov.local/
```

Удалим правила:

```shell
kubectl delete -f examples/07-header-modifiers.yaml
```

## HTTP traffic splitting

У нас запущено два приложения:

```shell
kubectl -n sample get svc
```
```txt
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
testapp-one   ClusterIP   10.233.40.161   <none>        80/TCP    9d
testapp-two   ClusterIP   10.233.11.88    <none>        80/TCP    9d
```

Предположим, что `testapp-one` - это текущая версия приложения. Разработчики выкатили новую версию `testapp-two` и задеплоили его рядом со старым.

Нам необходимо проверить работоспособность нового приложения, не выключая строго. Для этого можно использовать два типа расщепления трафика: Canary и Blue-green.

### Canary

Метод Canary подразумевает, что весь трафик по умолчанию идет на основное приложение. На новое перенаправляется только трафик в заголовке которого присутствует заранее оговоренное поле.

Например, для доступа к новому приложению в заголовок будем добавлять: `app-version: new`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: testapp-https-route
  namespace: sample
spec:
  parentRefs:
  - name: testapp-gw
    sectionName: https
  hostnames:
    - testapp.kryukov.local
  rules:
    - backendRefs:
        - name: testapp-one
          port: 80
    - matches:
        - headers:
          - name: app-version
            value: new
      backendRefs:
        - name: testapp-two
          port: 80
```

Добавим новые:

```shell
kubectl apply -f examples/08-canary.yaml
```

Доступ к старой версии приложения:

```shell
curl -vk https://testapp.kryukov.local/
```

Доступ к новой версии приложения:

```shell
curl -vk -H "app-version: new" https://testapp.kryukov.local/
```

Удалим правила:

```shell
kubectl delete -f examples/08-canary.yaml
```

### Blue-green

При помощи Blue-green мы можем осуществить постепенный переход на новую версию приложения.

Например, сначала отправлять 10% трафика на новое приложение. Через некоторое время 50%. Затем 80%. И в конце концов переключить весь трафик на новую версию.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: testapp-https-route
  namespace: sample
spec:
  parentRefs:
    - name: testapp-gw
      sectionName: https
  hostnames:
    - testapp.kryukov.local
  rules:
    - backendRefs:
      - name: testapp-one
        port: 80
        weight: 90
      - name: testapp-two
        port: 80
        weight: 10
```

```shell
kubectl apply -f examples/09-blue-green.yaml
```

Посылаем запросы минимум 10-ть раз:

```shell
curl -vk https://testapp.kryukov.local/
```
