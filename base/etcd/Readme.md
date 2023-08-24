# ETCD

Установка кластера etcd в kubernetes.

Это отдельный кластер etcd. Он не используется кубером для своей работы. Предназначен для использования другими 
приложениями. Например, для организации внешнего кластера postgresql.

## Helm chart

Самый простой способ установки - использовать helm chart от [Bitnami](https://bitnami.com/stack/etcd/helm).

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo etcd
```

Получаем файл values для исследования.

```shell
helm show values bitnami/etcd > values.yaml
```

## Конфигурация

Конфигурация находится в файле `my-values.yaml`.

## Установка

Если его нет, добавим namespace etcd:

```shell
kubectl create ns etcd
```

Создадим secret, содержащий пароль пользователя root.

```shell
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: etcd-root-password
  namespace: etcd
  labels:
    manual: "yes"
type: Opaque
stringData:
  PASSWORD: "password"
EOF
```

### ArgoCD

```shell
kubectl apply -f argoapp/01.yaml
```

### Helm chart

```shell
helm install etcd bitnami/etcd -f my-values.yaml
```

