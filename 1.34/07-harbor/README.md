# Harbor

Для работы Harbor должны быть запущены: [redis](../05-redis/) и [postgresql](../06-postgresql/).

## Helm

```shell
helm repo add harbor https://helm.goharbor.io
helm install harbor harbor/harbor -f harbor-values.yaml --create-namespace --namespace harbor
```

## ArgoCD

Ставим приложение (включает Harbor и HTTPRoute для Gateway API):

```shell
kubectl apply -f harbor-argo-app.yaml
```

Версия чарта: 1.18.2 (Harbor 2.14.2)

Harbor использует `expose.type: clusterIP`. TLS терминируется на Gateway API (Gateway `eg` в `envoy-gateway-system`).
