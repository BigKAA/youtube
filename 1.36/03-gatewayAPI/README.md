# Gateway API

Поскольку `Ingress` переходит в статус устаревшего, будем вместо него использовать `Gateway API` на базе Envoy.

Helm chart проекта использует oci хранилище в dockerhub. Поэтому смотрим последнюю версию "[Helm charts envoyproxy/gateway-helm](https://hub.docker.com/r/envoyproxy/gateway-helm/tags)".

Устанавливаем приложение.

```sh
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.6.1 \
  --set deployment.priorityClassName=high-priority \
  --set deployment.replicas=1 \
  --skip-crds \
  -n envoy-gateway-system --create-namespace
```

Ждем старта подов.

```sh
kubectl wait -n envoy-gateway-system --for=condition=Ready pods --selector "app.kubernetes.io/instance=eg"
```

Добавляем `kind: EnvoyProxy`

```sh
kubectl apply -f 01-EnvoyProxy-Config.yaml
```

Добавляем `kind: GatewayClass` и `kind: Certificate`

```sh
kubectl apply -f 02-gateway-class.yaml
kubectl apply -f 03-gateway-cert.yaml
```

**Важно!** В сертификате в дальнейшем указывайте имена хостов, которые будут использоваться для доступа к сервисам. После изменения делайте `rollout restart` для `Deploymnet` gateway. Имя `Deploymnet` непредсказуемое, поэтому придется искать его вручную.

Gateway будет глобальным, поэтому его нужно разместить в `envoy-gateway-system`. *Глобальный* - это значит, что на этом Gateway будут "висеть" все сайты нашего кластера.

Добавляем `kind: Gateway`

```sh
kubectl apply -f 04-gateway.yaml
```
