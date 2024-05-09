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
