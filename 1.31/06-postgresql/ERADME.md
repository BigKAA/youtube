# PosrgreSQL

Без фанатизма, один под. Для экспериментов.

## Manifests

```shell
kubectl create ns pg
kubectl -n pg apply -f manifests
```

## ArgoCD

```shell
kubectl apply -f argo/argo-app.yaml
```
