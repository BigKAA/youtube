# Gitlab

https://docs.gitlab.com/charts/installation/

Для создания PV в моём кластере используется NFS диск и соответствующий ему StorageClass - managed-nfs-storage.

## Prerequisites

Для деплоя приложений я использую ArgoCD. Вы можете использовать манифесты или helm charts. Что и где находится
можно посмотреть в соответствующих yaml файлов в директории argocd. 

### Postgresql

Поставим один под postgresql. Простейшая установка. Для прод необходимо ставить полнофункциональный кластер.

```shell
kubectl apply -f argocd/postgre-app.yaml
```

### Redis

```shell
kubectl apply -f argocd/redis-app.yaml
```

helm show values postgres-operator-charts/postgres-operator > operator/postgres-operator-values.yaml