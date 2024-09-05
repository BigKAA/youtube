# Harbor

Для работы Harbor должны быть запущены; [redis](../05-redis/) и [postgresql](../06-postgresql/).

## Helm

```shell
helm install harbor bitnami/harbor -f harbor-values.yaml --create-namespace --namespace harbor
```

## ArgoCD

```shell
kubectl apply -f harbor-argo-app.yaml
```
