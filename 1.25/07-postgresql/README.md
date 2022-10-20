# Database

На момент написания этого раздела ни один оператор баз данных не работал с 
версией 1.25 kubernetes.

Пришлось ставить простенькую базу самостоятельно.

```shell
kubectl create ns postgresql
kubectl -n postgresql apply -f postgresql/manifests
kubectl -n postgresql apply -f pgadmin/manifests
```

Оба приложения приземляются на ноду db1.kryukov.local