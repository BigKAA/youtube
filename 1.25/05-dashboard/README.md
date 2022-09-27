# Kubernetes dashboard

[Документация](https://github.com/kubernetes/dashboard).

Деплоим последнюю версию

```shell
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

Выводим наружу при помощи сервисов типа NodePort или LoadBalancer  или при помощи [Ingress](manifests/ingress.yaml). 

Добавляем [ServiceAccount и ClusterRoleBinding](00-admin-user.yaml).

```shell
kubectl create -f 00-admin-user.yaml
```

Получаем токен для доступа:

    kubectl -n kubernetes-dashboard get secret admin-user \
    -o go-template="{{.data.token | base64decode}}"
