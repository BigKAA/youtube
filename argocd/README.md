# Argo CD

[Документация](https://argo-cd.readthedocs.io/en/stable/)

## Установка

    # kubectl create namespace argocd
    # curl -o install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v2.0.1/manifests/install.yaml

Я разбил это файл на два: argo-1.yaml и argo-2.yaml. В первом файле находятся CRD и мы его менять не будем.

Во втором файле будем изменять аргументы командной строки.

    # kubectl apply -f
    # kubectl apply -f 

## Cert-manager

[cert-manager](https://cert-manager.io/docs/installation/kubernetes/) - утилита
для управления сертификатами.

    # kubectl -n argocd create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt \
    --key=/etc/kubernetes/ssl/ca.key

    # kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
    # kubectl get pods --namespace cert-manager

Namespace cert-manager создаётся автоматически.

## Настраиваем ingress для доступа.

    # kubectl apply -f 00-certs.yaml

Для argocd ставим отдельный ingress controller.
    
    # kubect apply -f 01-ingress-con.yaml

Добавляем ingress

    # kubectl apply -f 02-ingress.yaml

## Установка CLI

    # curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.0.1/argocd-linux-amd64
    # chmod +x /usr/local/bin/argocd
    # argocd version

## Пароль админа

    # kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

Добавим в /etc/hosts имя argocd.kryukov.local

    # argocd login argocd.kryukov.local:30443
    # argocd account update-password

## Добавление пользователя

Добавляем пользователя в argocd-cm

    # kubectl apply -f 03-argocd-cm.yaml

Добавляем пользователю роль админа в argocd-rbac-cm

    # kubectl apply -f 04-argocd-rbac-cm.yaml

Затем в командной строке получаем список

    # argocd account list

    # argocd account update-password --account artur
    *** Enter current password:        <---- admin password
    *** Enter new password:
    *** Confirm new password:
    Password updated

Логинимся новым пользователем в систему

    # argocd login argocd.kryukov.local:30443
    # argocd cluster list

Заходм в WEB интерфейс

    https://argocd.kryukov.local:30443/