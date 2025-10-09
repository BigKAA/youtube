# vCluster

- [vCluster](#vcluster)
  - [Предварительные требования](#предварительные-требования)
  - [Установка vCluster](#установка-vcluster)
    - [Values файл](#values-файл)
    - [Запуск виртуального кластера](#запуск-виртуального-кластера)
  - [Безопасность](#безопасность)
    - [Ограничение ресурсов](#ограничение-ресурсов)
    - [Rootless mode](#rootless-mode)
  - [Тестируем виртуальный кластер](#тестируем-виртуальный-кластер)
    - [Namespace](#namespace)
    - [Тестовое приложение](#тестовое-приложение)
  - [Синхронизация ресурсов](#синхронизация-ресурсов)
    - [Persistent Volumes](#persistent-volumes)
    - [Ingress controller](#ingress-controller)
  - [Удаление кластера](#удаление-кластера)


[Документация](https://www.vcluster.com/docs/)

Vcluster - это сертифицированные дистрибутивы Kubernetes, которые работают как изолированные виртуальные среды, встроенные в физический хост-кластер. Он улучшают изоляцию и гибкость для многопользовательской среды позволяет нескольким командам независимо работать в одной и той же инфраструктуре, минимизируя конфликты, повышая автономность и снижая затраты.

Виртуальные кластеры работают в пространствах имен (namespaces) хост-кластера, но функционируют как независимые среды Kubernetes. Каждая со своим собственным сервером API, плоскостью управления, синхронизатором и набором ресурсов.

## Предварительные требования

Перед установкой виртуального кластера посмотрите текущую [Политику жизненного цикла](https://www.vcluster.com/docs/vcluster/deploy/upgrade/supported_versions) проекта. В этом же документе находится [Матрица совместимости Kuberntes](https://www.vcluster.com/docs/vcluster/deploy/upgrade/supported_versions#kubernetes-compatibility-matrix).

Для дальнейшей работы нам потребуется установленный кластер Kubernetes, версия которого должна присутствовать в матрице совместимости. В моём случае это версия 1.33.1:

```shell
kubectl get nodes
```

```txt
NAME                STATUS   ROLES           AGE   VERSION
cr1.kryukov.local   Ready    control-plane   19d   v1.33.1
wr1.kryukov.local   Ready    worker          19d   v1.33.1
wr2.kryukov.local   Ready    worker          19d   v1.33.1
```

В кластере заранее установлены: Ingress controller, metrics-server, cert-manager, nfs-client-provisioner и MetaLB (провайдер сервисов типа LoadBalancer). Опционально можно поставить ArgoCD.

Я планирую предоставлять доступ к kube-api виртуального кластера при помощи ingress контроллера на хост кластере. Контроллер должен уметь транслировать https трафик без терминации ssl на kube-api виртуального сервера. В случае nginx ingress controller, он должен запускаться с параметром `--enable-ssl-passthrough=true`.

## Установка vCluster

Vсluster устанавливается в уже существующий кластер kubernetes. Для установки можно использовать приложение [vcluster](https://github.com/loft-sh/vcluster/releases/download/v0.25.1/vcluster-linux-amd64) или [helm chart](https://charts.loft.sh).

Для конфигурации виртуального кластера потребуется создать файл с его описанием - `vcluster.yaml`. По сути, это обычный [values-файл](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/) helm chart-а.

Я буду использовать helm chart:

```shell
helm repo add vcluster https://charts.loft.sh
helm repo update
```

### Values файл

Подготовим файл конфигурации `vcluster.yaml`:

```yaml
controlPlane:
  distro:
   k8s:
     enabled: true
     image:
       registry: ghcr.io
       repository: "loft-sh/kubernetes"
       tag: "v1.32.1"
```

```yaml
controlPlane:
  backingStore:
    etcd:
      deploy:
        enabled: true
        statefulSet:
          persistence:
            volumeClaim:
              enabled: true
              storageClass: "managed-nfs-storage"
              size: 5Gi  
```

```yaml
controlPlane:
  statefulSet:
    persistence:
      volumeClaim:
        storageClass: "managed-nfs-storage"
        size: 5Gi
```

```yaml
controlPlane:
  ingress:
    enabled: true
    host: vc1.kryukov.local
  proxy:
    extraSANs:
    - vc1.kryukov.local
    # - 192.168.218.180
exportKubeConfig:
  context: "vc1"
  server: https://vc1.kryukov.local
```

```yaml
integrations:
  metricsServer:
    enabled: true
    nodes: true
    pods: true
```

### Запуск виртуального кластера

```shell
helm install vc1 vcluster/vcluster -f values/01-values.yaml -n vc1 --create-namespace
```

После установки виртуального кластера доступен congig-файл, для доступа к нему:

```shell
kubectl -n vc1 get secret vc-vc1 --template={{.data.config}} | base64 -d > config.yaml
```

```shell
kubectl --kubeconfig=config.yaml get nodes
```

```txt
NAME                STATUS   ROLES    AGE     VERSION
wr2.kryukov.local   Ready    <none>   3m14s   v1.32.1
```

```shell
kubectl --kubeconfig=config.yaml get ns
```

```txt
NAME              STATUS   AGE
default           Active   13m
kube-node-lease   Active   13m
kube-public       Active   13m
kube-system       Active   13m
```

## Безопасность

### Ограничение ресурсов

Поскольку виртуальный кластер в нашем случае отображается на один namespace. То для ограничения ресурсов используются стандартные `ResourceQuota` и `LimitRange`.

Их можно создавать как при помощи стандартных манифестов, так и определять в values файле виртуального кластера.

*Не забывайте, что приложения control plane виртуального кластера находятся в том же namespace. И на них тоже будут распространяться эти ограничения.*

```yaml
policies:
  resourceQuota:
    enabled: true
    quota:
      cpu: "4"
      memory: "5Gi"
      limits.memory: "5Gi"
      pods: "15"
      requests.storage: "20Gi"
  limitRange:
    enabled: true
    default:
      memory: 512Mi
      cpu: "1"
    defaultRequest:
      memory: 128Mi
      cpu: 100m
```

Обновим виртуальный кластер:

```shell
helm upgrade vc1 vcluster/vcluster -f values/02-values-quotas.yaml -n vc1
```

```txt
Release "vc1" has been upgraded. Happy Helming!
NAME: vc1
LAST DEPLOYED: Sat Jun 21 14:24:24 2025
NAMESPACE: vc1
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

Посмотрим текущую `ResourceQuota`:

```shell
kubectl -n vc1 get ResourceQuota vc-vc1 --no-headers | tr ',' '\n'
```

```yaml
vc-vc1   count/configmaps: 5/100
 count/endpoints: 7/40
 count/persistentvolumeclaims: 1/20
 count/pods: 4/20
 count/secrets: 4/100
 count/services: 8/20
 cpu: 340m/4
 memory: 570Mi/5Gi
 pods: 4/15
 requests.cpu: 340m/10
 requests.ephemeral-storage: 12Gi/60Gi
 requests.memory: 570Mi/20Gi
 requests.storage: 5Gi/20Gi
 services.loadbalancers: 0/1
 services.nodeports: 0/0   
 limits.cpu: 3100m/20
 limits.ephemeral-storage: 32Gi/160Gi
 limits.memory: 2830Mi/5Gi   9m35s
```

И `LimitRange`:

```shell
kubectl -n vc1 get LimitRange vc-vc1 -o=jsonpath='{.spec.limits[*]}' | jq
```

```json
{
  "default": {
    "cpu": "1",
    "ephemeral-storage": "8Gi",
    "memory": "512Mi"
  },
  "defaultRequest": {
    "cpu": "100m",
    "ephemeral-storage": "3Gi",
    "memory": "128Mi"
  },
  "type": "Container"
}
```

В случае использования нескольких namespaces для виртуального кластера, придётся создавать квоты и лимиты для каждого namespace отдельно.

### Rootless mode

Запускать контейнеры с правами пользователя root, не хорошо. Поэтому добавим в values файл параметры определяющие `SecurityContext`:

```yaml
controlPlane:
  statefulSet:
    security:
      podSecurityContext:
        fsGroup: 12345
      containerSecurityContext:
        runAsUser: 12345
        runAsGroup: 12345  
        runAsNonRoot: true
```

Обновим виртуальный кластер:

```shell
helm upgrade vc1 vcluster/vcluster -f values/03-values-rootless.yaml -n vc1
```

Посмотрим, как теперь выглядит конфигурация:

```shell
kubectl -n vc1 get deployment vc1 -o=jsonpath="{.spec.template.spec.containers[*].securityContext}" | jq
```

```json
{
  "allowPrivilegeEscalation": false,
  "runAsGroup": 12345,
  "runAsNonRoot": true,
  "runAsUser": 12345
}
```

## Тестируем виртуальный кластер

### Namespace

```shell
kubectl --kubeconfig=config.yaml create ns test
```

```txt
namespace/test created
```

```shell
kubectl --kubeconfig=config.yaml get ns
```

```txt
NAME              STATUS   AGE
default           Active   20m
kube-node-lease   Active   20m
kube-public       Active   20m
kube-system       Active   20m
test              Active   26s
```

Посмотрим список namespaces в хост кластере:

```shell
kubectl get ns
```

```txt
NAME               STATUS   AGE
argocd             Active   127m
calico-apiserver   Active   19d
calico-system      Active   19d
cert-manager       Active   140m
default            Active   19d
ingress-nginx      Active   132m
kube-node-lease    Active   19d
kube-public        Active   19d
kube-system        Active   19d
metallb-system     Active   143m
tigera-operator    Active   19d
vc1                Active   21m
```

Namespace test в списке отсутствует. Логично. Он же виртуальный.

### Тестовое приложение

Установим тестовое приложение:

```shell
kubectl --kubeconfig=config.yaml -n test apply -f manifests/01-test-app.yaml
```

```txt
deployment.apps/test-app created
service/test-app created
```

```shell
kubectl --kubeconfig=config.yaml -n test get all
```

```txt
NAME                            READY   STATUS    RESTARTS   AGE
pod/test-app-59fdcf645c-2wl6k   1/1     Running   0          17s

NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/test-app   ClusterIP   10.233.2.3   <none>        80/TCP    17s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/test-app   1/1     1            1           17s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/test-app-59fdcf645c   1         1         1       17s
```

Посмотрим, что появилось в namespace vc1 в хост кластере:

```shell
kubectl -n vc1  get all | grep test-app
```

```txt
pod/test-app-59fdcf645c-2wl6k-x-test-x-vc1       1/1     Running   0          43s
service/test-app-x-test-x-vc1                ClusterIP      10.233.2.3      <none>        80/TCP                   43s
```

Присутствуют только под и сервис.

Попробуем подключиться к приложению:

```shell
kubectl --kubeconfig=config.yaml -n test port-forward svc/test-app 8080:80 
```

```shell
curl http://localhost:8080
```

```txt
Hostname: test-app-76984f8c45-d8fzr
IP: 127.0.0.1
IP: ::1
IP: 10.233.109.241
IP: fe80::803f:9dff:fee2:1a65
RemoteAddr: 127.0.0.1:43562
GET / HTTP/1.1
Host: localhost:8080
User-Agent: curl/8.5.0
Accept: */*
```

Поскольку сервис отображается на хост кластер, можно подключиться к нему. Но это может сделать только админ хост кластера. А не пользователь виртуального кластера.

## Синхронизация ресурсов

Виртуальный кластер позволяет "пробрасывать" (синхронизировать) некоторые типы ресурсов между хост и виртуальными кластерами. Подробности можно посмотреть в [документации](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync).

В yaml файле есть специальные секции:

```yaml
sync:
  toHost:
    ...
  fromHost:
    ...
```

### Persistent Volumes

Посмотрим пример использования `StorageClass` хост кластера внутри виртуального кластера.

В моём случае, на хост кластере установлен `nfs-client-provisioner`. И соответствующий ему `StorageClass`: `managed-nfs-storage`.

По умолчанию проброс `StorageClass` включен в режиме `auto`.

```yaml
sync:
  fromHost:
    storageClasses:
      enabled: auto
```

Это значит, что `StorageClass` в виртуальном сервере не виден.

```shell
kubectl --kubeconfig=config.yaml get StorageClass
```

```txt
No resources found
```

Проброс PVC на хост кластер включён по умолчанию. См. [этот список](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/#enabled-by-default).

Добавим в файл values:

```yaml
sync:
  fromHost:
    storageClasses:
      enabled: true
```

Обновим виртуальный кластер:

```shell
helm upgrade vc1 vcluster/vcluster -f values/04-values-sync-storage.yaml -n vc1
```

Запросим список `StorageClass`:

```shell
kubectl --kubeconfig=config.yaml get StorageClasses
```

```txt
NAME                  PROVISIONER         RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
managed-nfs-storage   kryukov.local/nfs   Delete          Immediate           false                  9s
```

Попробуем в обратную сторону. Создадим PVC в виртуальном кластере с указанием требуемого `StorageClass`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  labels:
    app.kubernetes.io/name: test-app
    app.kubernetes.io/instance: test-app
spec:
  storageClassName: managed-nfs-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Применим манифест:

```shell
kubectl --kubeconfig=config.yaml -n test apply -f manifests/02-pvc.yaml
```

Посмотрим наличие PVC в виртуальном кластере:

```shell
kubectl --kubeconfig=config.yaml -n test get pvc
```

```txt
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
test-pvc   Bound    pvc-39cc1c8c-d93e-4063-b9ce-eb8a0171a8e6   1Gi        RWX            managed-nfs-storage   <unset>                 5s
```

*Ограничение PV можно делать при помощи `ResourceQuota`*

Удалим PVC:

```shell
kubectl --kubeconfig=config.yaml -n test delete pvc test-pvc
```

```txt
persistentvolumeclaim "test-pvc" deleted
```

### Ingress controller

Что бы не поднимать отдельные Ingress контроллеры для каждого виртуального кластера, можно внутри этого кластера пользоваться ingress контроллером, установленным на хост кластере. Для этого необходимо экспортировать соответствующие `kind: Ingress` из виртуальных кластеров в хост кластер.

В хост кластере установлен Ingress контроллер и добавлен соответствующий ему `IngressClass`:

```shell
kubectl get IngressClass
```

```txt
NAME             CONTROLLER             PARAMETERS   AGE
system-ingress   k8s.io/ingress-nginx   <none>       25h
```

Добавим в values файл разрешение для экспорта ingress на хост кластер и импорта ingressClass в виртуальный кластер.

```yaml
sync:
  toHost:
    ingresses:
      enabled: true
  fromHost:
    ingressClasses:
      enabled: true
```

Применим изменения:

```shell
helm upgrade vc1 vcluster/vcluster -f values/05-values-sync-ingress.yaml -n vc1
```

Посмотрим, какой IngressClass был импортирован:

```shell
kubectl --kubeconfig=config.yaml get ingressclass
```

```txt
NAME             CONTROLLER             PARAMETERS   AGE
system-ingress   k8s.io/ingress-nginx   <none>       74m
```

Применим манифест Ingress:

```shell
kubectl --kubeconfig=config.yaml -n test apply -f manifests/03-ingress.yaml
```

Немного подождем, пока контроллер обработает Ingress и подставит `LoadBalancer IP`.

Смотрим на хост кластере:

```shell
kubectl -n vc1 get Ingress
```

В виртуальном кластере:

```shell
kubectl --kubeconfig=config.yaml -n test get Ingress
```

Попробуем обратиться к приложению:

```shell
curl -k https://vc1-test-app.kryukov.local/
```

```yaml
Hostname: test-app-59fdcf645c-2wl6k
IP: 127.0.0.1
IP: ::1
IP: 10.233.109.195
IP: fe80::e831:3bff:feb5:4365
RemoteAddr: 10.233.124.133:53810
GET / HTTP/1.1
Host: vc1-test-app.kryukov.local
User-Agent: curl/8.5.0
Accept: */*
X-Forwarded-For: 127.0.0.1
X-Forwarded-Host: vc1-test-app.kryukov.local
X-Forwarded-Port: 443
X-Forwarded-Proto: https
X-Forwarded-Scheme: https
X-Real-Ip: 127.0.0.1
X-Request-Id: f0c8bae8965e778f84672cc16ee0e2be
X-Scheme: https
```

## Удаление кластера

Удалить виртуальный кластер можно командой:

```shell
helm uninstall vc1 -n vc1
kubectl delete namespace vc1
```
