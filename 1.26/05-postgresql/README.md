# Database

Два варианта установки postgresql:

* Простой. Один под базы данных.
* Кластер с patrony на базе проекта spilo.

## Одиночная база

```shell
kubectl create ns pg
kubectl -n pg apply -f postgresql/manifests
kubectl -n pg apply -f pgadmin/manifests
```

## spilo

По умолчанию использует PV `storageClass: managed-nfs-storage`.

```shell
helm install pg spilo/spilo -n pg --create-namespace 
kubectl -n pg apply -f pgadmin/manifests
```