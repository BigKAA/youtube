# Argo CD

[Документация](https://argo-cd.readthedocs.io/en/stable/)

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.0.0/manifests/install.yaml

# Установка CLI

    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.0.0/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
    argocd version

# CA сикрет

    kubectl -n argocd create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt \
    --key=/etc/kubernetes/ssl/ca.key

# Пароль админа

    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    argocd login argocd.kryukov.local:30443
    argocd account update-password

# Добавление пользователя

Добавляем пользователя в argocd-cm

Добавляем пользователю роль админа в argocd-rbac-cm

Затем в командной строке получаем список

    argocd account list

    # argocd account update-password --account artur
    *** Enter current password:        <---- admin password
    *** Enter new password:
    *** Confirm new password:
    Password updated

Логинимся этим пользователем в систему

    argocd login argocd.kryukov.local:30443

Подключение кластера

    argocd cluster add kubernetes-admin@cluster.local # контекст кластера из config файла
    argocd cluster list
