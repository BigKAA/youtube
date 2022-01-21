# Kubernetes dashboard

[Документация](https://github.com/kubernetes/dashboard).

Загружаем последнюю версию.

    wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.4.0/aio/deploy/recommended.yaml

Выводим наружу или через service NodePort или через [Ingress](manifests/ingress.yaml).

Добавляем [ServiceAccount и ClusterRoleBinding](manifests/admin_user.yaml).

Получаем токен для доступа:

    kubectl -n kubernetes-dashboard get secret \
    $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") \
    -o go-template="{{.data.token | base64decode}}"
