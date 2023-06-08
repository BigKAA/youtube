# Gitlab

https://docs.gitlab.com/charts/installation/

```shell
kubectl create ns gitlab
```

## Postgresql

Поставим один под postgresql. Простейшая установка. Для прод необходимо ставить полнофункциональный кластер.

```shell
kubectl -n gitlab apply -f postgresql/manifests
```


helm show values postgres-operator-charts/postgres-operator > operator/postgres-operator-values.yaml