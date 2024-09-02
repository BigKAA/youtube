# Установка приложений

## Вспомогательные компоненты

### PriorityClass

```shell
kubectl apply -f 00-priorityclass.yaml
```

### Cert-manager

```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml
```

## CA и ClusterIssuer

Для работы нам потребуется свой CA и ClusterIssuer, который будет использован для подписи различных сертификатов.

```shell
kubectl apply -f CA/ca.yaml
```

Импортируем сертификат CA в локальный файл.

```shell
kubectl -n cert-manager get secrets dev-ca -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
```

Полученный сертификат необходимо добавить в список доверенных сертификатов на всех ваших машинах,
приложения которых будут пользоваться вашим кластером и его приложениями.

На машине, где запущен кластер k3s:

1. Создаём файл `/etc/pki/ca-trust/source/anchors/dev-ca.pem`, содержащий полученный сертификат.
2. `update-ca-trust extract`
3. Желательно сделать reboot. (*Так будет быстрее, чем перезапускать все приложения на сервере*).

### Добавление сертификата CA в Ubuntu

```shell
sudo mkdir /usr/local/share/ca-certificates/extra
```

```shell
sudo vim /usr/local/share/ca-certificates/extra/dev-ca.crt
```

```shell
sudo update-ca-certificates
```

### Добавление сертификата CA в Rocky Linux

```shell
vim /etc/pki/ca-trust/source/anchors/dev-ca.crt
```

```shell
update-ca-trust force-enable
update-ca-trust extract
```

## Ingress controller

Устанавливаем чарт. Можно при помощи встроенного в k3s helm.

```shell
kubectl apply -f 01-ingress-controller.yaml
```

Проверяем:

```shell
kubectl -n ingress-nginx get all
curl http://192.168.218.189
```

## ArgoCD

```shell
kubectl create ns argo-cd
```

Создадим сикрет содержащий сертификат CA.

```shell
kubectl create secret generic -n argo-cd dev-ca-certs --from-file=dev-ca.pem=ca.crt
```

Запускаем ArgoCD

```shell
kubectl apply -f 02-argocd.yaml
```

Остальные приложения ставим либо при помощи ArgoCD, либо в ручную.

## Reloader

https://github.com/stakater/Reloader

ArgoCD:

```shell
kubectl apply -f argocd-apps/reloader-app.yaml
```

или

```shell
kubectl apply -f manifests/reloader/
```

## PostgreSQL

Однонодовый PostgreSQL и pgadmin.

ArgoCD:

```shell
kubectl apply -f argocd-apps/postgre-app.yaml
```

или

```shell
kubectl create ns psql
kubectl -n psql apply -f manifests/psql/postgresql.yaml
```

## Redis

ArgoCD:

```shell
kubectl apply -f argocd-apps/redis-app.yaml
```

или

```shell
kubectl create ns redis
kubectl apply -f charts/redis.yaml
```

## Minio

ArgoCD:

```shell
kubectl apply -f argocd-apps/minio-app.yaml
```

или

```shell
kubectl apply -f charts/minio.yaml
```

## Minio console

ArgoCD:

```shell
kubectl apply -f argocd-apps/minio-console-app.yaml
```

или

```shell
kubectl -n minio apply -f manifests/minio-console/minio-console.yaml
```

## Mail relay

ArgoCD:

```shell
kubectl apply -f argocd-apps/mail-relay-app.yaml
```

или

```shell
kubectl create ns mail-relay
kubectl -n mail-relay apply -f manifests/mail-relay/
```

## Harbor

База данных `harbor`

ArgoCD:

```shell
kubectl apply -f argocd-apps/harbor-app.yaml
```

или:

```shell
kubectl create ns harbor
kubectl apply -f charts/harbor.yaml
```

## Gitlab

Перед запуском GitLab требуется провести подготовительные действия.

```shell
kubectl create ns gitlab
```

Создаём сикреты, необходимые для работы gitlab:

```shell
kubectl -n gitlab apply -f gitlab-secrets
```

Создаём базу данных `gitlab` в PostgreSQL.

В minio создаём buckets:

- `gitlab-lfs-storage`
- `gitlab-artifacts-storage`
- `gitlab-uploads-storage`
- `gitlab-packages-storage`
- `gitlab-backup-storage`
- `gitlab-tmp-storage`

ArgoCD:

Почему то, в ArgoCD чарт не работает. Поэтому ставим через helm который встроен в k3s

```shell
kubectl apply -f charts/gitlab.yaml
```

## GitLab runner

В WEB интерфейсе создай runner. Получите токен и подставьте eго значение в Secret.

```shell
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: dev-gitlab-runner
  namespace: gitlab
  labels:
    manual: "yes"
type: Opaque
stringData:
  runner-registration-token: ""
  # тут подставляем полученный в WEB интерфейсе токен
  runner-token: "glrt-qZeoBLU_jZ3yDsFtdT7k"
  
  # S3 cache parameters
  accesskey: "admin"
  secretkey: "password"
EOF
```

В minio добавляем бакет `dev-runner-cache`.

```shell
kubectl apply -f charts/gitlab-runner.yaml
```
