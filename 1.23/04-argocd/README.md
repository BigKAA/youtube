#ArgoCD

## Cert-manager

[cert-manager](https://cert-manager.io/docs/installation/kubernetes/) - утилита
для управления сертификатами.

    # kubectl create namespace argocd
    # kubectl -n argocd create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/pki/ca.crt \
    --key=/etc/kubernetes/pki/ca.key

    # kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml

Namespace cert-manager создаётся автоматически.

## Установка

Скачайте манифест.

    curl -o install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v2.2.3/manifests/install.yaml

Откройте его в редакторе и найдите:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cmd-params-cm
```

Добавьте в него следующие строки:

```yaml
data:
  server.insecure: "true"
  server.staticassets: "/shared/app"
  server.log.format: "json"
  server.log.level: "info"
```

Установите ArgoCD:

    kubectl -n argocd apply -f install.yaml

Создадим сертификат и ingress:

    kubectl -n argocd apply -f 00-certs.yaml -f 01-ingress.yaml

## CLI

Получим пароль пользователя по умолчанию.

    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

Получим что то типа: usfpsGjWsI5c-L6K

Скачаем утилиту.

    curl -sSL -o /usr/local/bin/argocd  https://github.com/argoproj/argo-cd/releases/download/v2.2.3/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
    argocd version

Подключимся к argocd:

    argocd login argocd.kryukov.local:443 --grpc-web

Пользователь admin. Пароль мы получили на предыдущем шаге.

Сменим пароль пользователя admin.

    argocd account update-password --grpc-web

Добавим нового пользователя и rbac правила.

    kubectl -n argocd apply -f 02-argocd-cm.yaml -f 03-argocd-rbac-cm.yaml

Затем в командной строке получаем список пользователей:

    argocd account list --grpc-web

Меняем пароль у нового пользователя:

    argocd account update-password --account artur --grpc-web
    *** Enter current password:        <---- admin password
    *** Enter new password:
    *** Confirm new password:
    Password updated

Заходим в WEB интерфейс https://argocd.kryukov.local
