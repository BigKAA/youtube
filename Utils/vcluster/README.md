# vCluster

- [vCluster](#vcluster)
  - [Предварительные требования](#предварительные-требования)
  - [Установка vCluster](#установка-vcluster)
    - [Values файл](#values-файл)
    - [Запуск виртуального кластера](#запуск-виртуального-кластера)

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

