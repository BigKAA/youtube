# Harbor

Для работы Harbor должны быть запущены: [redis](../05-redis/) и [postgresql](../06-postgresql/).

Используется официальный [helm chart](https://github.com/goharbor/harbor-helm) от goharbor.
Chart помещён в директорию `chart/harbor/` в git-репозитории.

## Helm

```shell
helm install harbor ./chart/harbor -f harbor-values.yaml --create-namespace --namespace harbor
```

## ArgoCD

Ставим приложение (включает Harbor и HTTPRoute для Gateway API):

```shell
kubectl apply -f harbor-argo-app.yaml
```

Версия чарта: 1.18.2 (Harbor 2.14.2)

Harbor использует `expose.type: clusterIP`. TLS терминируется на Gateway API (Gateway `eg` в `envoy-gateway-system`).
