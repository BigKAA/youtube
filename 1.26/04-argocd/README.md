# ArgoCD

[Документация](https://argo-cd.readthedocs.io/en/stable/).

Скачаем манифест и внесём в него некоторые изменения. Не используйте latest версию. Всегда выбирайте 
конкретную версию ArgoCD.

```shell
curl https://raw.githubusercontent.com/argoproj/argo-cd/v2.6.7/manifests/install.yaml -o 01-argocd.yaml
```

В полученном файле исправим логирование и сервисы.

Находим configmap:

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

Устанавливаем ArgoCD:

```shell
kubectl create namespace argocd
```
```shell
kubectl -n argocd create -f 01-2.9.3-argocd.yaml
```

Дальше необходимо решить, как будет осуществляться доступ к ArgoCD.
* Service NodePort -> [02-service-nodeport.yaml](02-service-nodeport.yaml)
* Service LoadBalancer -> [03-service-lb.yaml](03-service-lb.yaml)
* Ingress -> [04-certs.yaml](04-certs.yaml) и [05-ingress.yaml](05-ingress.yaml)

Соответственно выбираем один из вариантов:

```shell
kubectl -n argocd create -f 02-service-nodeport.yaml
```

```shell
kubectl -n argocd create -f 03-service-lb.yaml
```

```shell
kubectl -n argocd create -f 03-service-lb-k3s.yaml
```

```shell
kubectl -n argocd create -f 04-certs.yaml -f 05-ingress.yaml
```

## Установка ArgoCD CLI

CLI можно ставить на любом компьютере. Как вариант, на первой 
control ноде.

```shell
wget https://github.com/argoproj/argo-cd/releases/download/v2.9.3/argocd-linux-amd64
mv -f argocd-linux-amd64 /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd
argocd version
```

## Локальные пользователи.

После установки пароль администратора находится в secret argocd-initial-admin-secret. 

```shell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Логинимся с этим паролем в cli. У меня доступ через ingress controller. 

```shell
argocd login argocd.kryukov.local:443 --grpc-web
```

Пользователь admin. Пароль из сикрета мы получили выше.

Сменим пароль пользователя admin.

```shell
argocd account update-password --grpc-web
```

Добавим нового пользователя и rbac правила.

```shell
kubectl -n argocd apply -f 06-argo-cm.yaml -f 07-argo-rbac.yaml
```

Получаем список пользователей:

```shell
argocd account list --grpc-web
```

Меняем пароль у нового пользователя:

    argocd account update-password --account artur --grpc-web
    *** Enter current password:        <---- admin password
    *** Enter new password:
    *** Confirm new password:
    Password updated

Заходим в WEB интерфейс https://argocd.kryukov.local

## Helm

```shell
helm repo add https://argoproj.github.io/argo-helm
```

```shell
helm install argocd argocd/argo-cd -f argo-values.yaml -n argocd --create-namespace
```

Как генерировать пароль для админа написано в комментариях к secret в файле `argo-values.yaml`.