# Redis

## Helm

```shell
helm repo update
```

```shell
helm install redis bitnami/redis -f redis-values.yaml --create-namespace --namespace redis
```

## ArgoCD

```shell
kubectl apply -f redis-argo-app.yaml
```
