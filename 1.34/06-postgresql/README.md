# PostgreSQL

## ArgoCD

Добавляем oci repo bitnami (если ещё не добавлен):

```shell
kubectl apply -f ../05-redis/bitnami-argo-repo.yaml
```

Ставим PostgreSQL:

```shell
kubectl apply -f argo/argo-app.yaml
```

Ставим pgAdmin:

```shell
kubectl apply -f argo/pgadmin-argo-app.yaml
```

Версия чарта PostgreSQL: 18.2.3 (PostgreSQL 18.1.0)

## Параметры

- Namespace: `pg`
- Service: `postgresql.pg.svc:5432` (NodePort: 32543)
- User: `artur`
- Database: `harbor`
- StorageClass: `managed-nfs-storage`
- pgAdmin доступен по адресу: `pg.kryukov.lan`
