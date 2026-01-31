# Harbor

Для работы Harbor должны быть запущены: [redis](../05-redis/) и [postgresql](../06-postgresql/).

## Helm

```shell
helm install harbor bitnami/harbor -f harbor-values.yaml --create-namespace --namespace harbor
```

## ArgoCD

Добавляем oci repo bitnami:

```shell
kubectl apply -f bitnami-argo-repo.yaml
```

Ставим приложение (включает Harbor и HTTPRoute для Gateway API):

```shell
kubectl apply -f harbor-argo-app.yaml
```

Версия чарта: 27.0.3 (Harbor 2.13.2)

Harbor использует `exposureType: proxy` (nginx). TLS терминируется на Gateway API (Gateway `eg` в `envoy-gateway-system`).
