# Gateway API

Поскольку `Ingress` переходит в статус устаревшего, будем вместо него использовать `Gateway API` на базе Envoy.

Helm chart проекта использует oci хранилище в dockerhub. Поэтому смотрим последнюю версию "[Helm charts envoyproxy/gateway-helm](https://hub.docker.com/r/envoyproxy/gateway-helm/tags)".

**Важно!** Начиная с v1.9.0 чарт включает не только CRD Envoy Gateway, но и CRD Gateway API. CRD Gateway API мы уже применили отдельно в `01-base-app` (они нужны cert-manager). Поэтому чарт ставим с `--set crds.enabled=false`, а собственные CRD Envoy Gateway (`EnvoyProxy` и др.) применяем вручную из релизных ассетов.

Применяем CRD Envoy Gateway. Манифест большой, поэтому используем server-side apply:

```sh
kubectl apply --server-side --force-conflicts \
  -f https://github.com/envoyproxy/gateway/releases/download/v1.9.0/envoy-gateway-crds.yaml
```

Устанавливаем приложение.

```sh
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.0 \
  --set deployment.priorityClassName=high-priority \
  --set deployment.replicas=1 \
  --set crds.enabled=false \
  -n envoy-gateway-system --create-namespace
```

**Порядок важен**: CRD применяются до установки чарта. Если контроллер стартует раньше CRD, он кэширует их отсутствие, Gateway не сможет найти `EnvoyProxy` и останется в статусе `Accepted=False` (лечится рестартом `deployment/envoy-gateway`).

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

**Важно!** В сертификате в дальнейшем указывайте имена хостов, которые будут использоваться для доступа к сервисам. После изменения делайте `rollout restart` для `Deployment` envoy proxy. Имя `Deployment` непредсказуемое (`envoy-<namespace>-<gateway>-<hash>`), поэтому придется искать его вручную:

```sh
kubectl -n envoy-gateway-system get deploy | grep envoy-
```

Gateway будет глобальным, поэтому его нужно разместить в `envoy-gateway-system`. _Глобальный_ - это значит, что на этом Gateway будут "висеть" все сайты нашего кластера.

Добавляем `kind: Gateway`

```sh
kubectl apply -f 04-gateway.yaml
```

Проверяем результат. Gateway должен получить адрес из пула MetalLB и перейти в состояние `Programmed=True`:

```sh
kubectl -n envoy-gateway-system get gateway eg
kubectl -n envoy-gateway-system get envoyproxy main
kubectl -n envoy-gateway-system get svc | grep envoy-
```

Должен появиться сервис типа `LoadBalancer` с именем `envoy-envoy-gateway-system-eg-<hash>` и внешним IP из аннотации `metallb.io/loadBalancerIPs` (в нашем случае `192.168.218.180`). Проверяем доступность (404 — ожидаемо, routes еще не подключены):

```sh
curl http://192.168.218.180/
```
