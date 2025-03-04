# Redis

## Helm

```shell
helm repo update
```

```shell
helm install redis bitnami/redis -f redis-values.yaml --create-namespace --namespace redis
```

## ArgoCD

Добавляем oci repo bitnami:

```shell
kubectl apply -f bitnami-argo-repo.yaml
```

Ставим приложение:

```shell
kubectl apply -f redis-argo-app.yaml
```
