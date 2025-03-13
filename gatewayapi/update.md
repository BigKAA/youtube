# Копаем глубже

## Два HTTPS listeners

Проверим, как cert-manager работает с двумя HTTPS listeners. Добавим в Gateway второй HTTPS listener:

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
          from: Same
    - name: https
      protocol: HTTPS
      port: 8443
      hostname: sample.kryukov.local
      tls:
        mode: Terminate
        certificateRefs:
          - name: sample-tls
            namespace: sample
      allowedRoutes:
        namespaces:
          from: Same
    - name: https2
      protocol: HTTPS
      port: 8443
      hostname: sample2.kryukov.local
      tls:
        mode: Terminate
        certificateRefs:
          - name: sample-2tls
            namespace: sample
      allowedRoutes:
        namespaces:
          from: Same
```

Будем ссылаться на тоже самое приложение.

Применим изменения:

```bash
kubectl apply -f manifests/06-gateway2.yaml
```

Проверяем наличие нового сертификата:

```bash
kubectl -n sample get secrets
```

Создаём новый HTTPRoute:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: sample2-https
  namespace: sample
spec:
  parentRefs:
    - name: traefik-gateway
      sectionName: https2
      kind: Gateway
  hostnames:
    - "sample2.kryukov.local"
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

Применим изменения и дополнения:

```bash
kubectl apply -f manifests/07-https2-route.yaml
```

Проверяем подключение к `https://sample2.kryukov.local`.

## TCPRoute

### Тестовое приложение

Подготовим контейнер с включенным SSH:

```shell
cd container-ssh
docker build -t lunar.kryukov.biz:10443/library/ssh/ubuntu_ssh:24.04 .
docker push lunar.kryukov.biz:10443/library/ssh/ubuntu_ssh:24.04
cd ..
```

Запускаем приложение:

```bash
kubectl apply -f manifests/08-container-ssh.yaml
```

### Настройка traefik

Для включения TCP Entrypoint в values чарта добавим секцию ports:

```yaml
ports:
  ssh:
    port: 3000
    expose:
      default: true
    exposedPort: 3000
    protocol: TCP
```

Поскольку поддержка TCPRoute в traefik является экспериментальной, добавим параметр `experimentalChannel: true`:

```yaml
providers:
  kubernetesGateway:
    enabled: true
    experimentalChannel: true
```

Применим изменения:

```bash
kubectl apply -f manifests/09-application-treaefik.yaml
```

### Новый Gateway

Создадим отдельный Gateway для SSH.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik-gateway-ssh
  namespace: sample
spec:
  gatewayClassName: traefik
  listeners:
    - name: ssh
      protocol: TCP
      port: 3000
      allowedRoutes:
        namespaces:
          from: Same
```

Применим изменения:

```bash
kubectl apply -f manifests/10-gateway3.yaml
```

### Создание TCPRoute

Добавляем TCPRoute:

```yaml
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: ssh
  namespace: sample
spec:
  parentRefs:
    - name: traefik-gateway-ssh
      sectionName: ssh
      kind: Gateway
  rules:
    - backendRefs:
        - name: ubuntu-ssh
          namespace: sample
          port: 22
```

Добавим манифест:

```bash
kubectl apply -f manifests/11-tcproute.yaml
```

Проверим подключение к ssh серверу в контейнере:

```bash
ssh artur@sample.kryukov.local -p 3000
```
