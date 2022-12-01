# Первая control нода

После того как мы подготовили сервера, запустили необходимые сервисы, необходимо настроить первую control ноду
кластера.

Для начала нам необходимо понять, какие версии api поддерживает установленная версия kubeadm.

```shell
kubeadm config print init-defaults | grep apiVersion
```

Что дальше будут приведены примеры для следующих версий api:

* InitConfiguration - kubeadm.k8s.io/v1beta3
* ClusterConfiguration - kubeadm.k8s.io/v1beta3

Для KubeProxyConfiguration и KubeletConfiguration следует использовать последнюю версию api для вашей текущей 
версии kubernetes. Посмотреть все варианты можно в [документации](https://kubernetes.io/docs/reference/config-api/).

Создадим директорию `/etc/kubernetes`:

```shell
mkdir /etc/kubernetes
```

Добавим в неё файл `kubeadm-config.yaml` следующего содержания:

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
localAPIEndpoint:
  advertiseAddress: 192.168.218.171
  bindPort: 6443
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
  imagePullPolicy: IfNotPresent
  name: control1.kryukov.local
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
certificatesDir: /etc/kubernetes/pki
clusterName: cluster.local
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: "registry.k8s.io"
apiServer:
  timeoutForControlPlane: 4m0s
  extraArgs:
    authorization-mode: Node,RBAC
    bind-address: 0.0.0.0
    service-cluster-ip-range: "10.233.0.0/18"
    service-node-port-range: 30000-32767
kubernetesVersion: "1.25.4"
controlPlaneEndpoint: 192.168.218.189:7443
networking:
  dnsDomain: cluster.local
  podSubnet: "10.233.64.0/18"
  serviceSubnet: "10.233.0.0/18"
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
bindAddress: 0.0.0.0
clusterCIDR: "10.233.64.0/18"
ipvs:
  strictARP: True
mode: ipvs
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
clusterDNS:
- 169.254.25.10
systemReserved:
  memory: 512Mi
  cpu: 500m
  ephemeral-storage: 2Gi
# Default: "10Mi"
containerLogMaxSize: 1Mi
# Default: 5
containerLogMaxFiles: 3
```

Этот файл мы будем использовать для инициализации кластера при помощи kubeadm. 

## initConfiguration

[Документация](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-InitConfiguration).

Основные параметры, на которые следует обратить внимание.

```yaml
localAPIEndpoint:
  advertiseAddress: 192.168.218.171
  bindPort: 6443
nodeRegistration:
  name: control1.kryukov.local
  criSocket: "unix:///var/run/containerd/containerd.sock"
  imagePullPolicy: IfNotPresent
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
```

* **localAPIEndpoint** - определяем IP адрес и порт, на котором на этой ноде будет слушать запросы kubernetes API сервер.
  Тут надо указывать IP машины, а не кластерный IP адрес, используемый в High availability конфигурации. Если эти
  параметры не указывать, kubeadm попытается автоматически определить значения. Если у вас несколько сетевых интерфесов,
  лучше явно определить параметры localAPIEndpoint.  
* **nodeRegistration** - содержит поля, относящиеся к регистрации новой control ноды кластера.
  * **name** - имя хоста.
  * **criSocket** - определяем способ подключения к системе контейнеризации, установленной на ноде.
  * **imagePullPolicy** - значение по умолчанию `IfNotPresent`.
  * **taints** - набор tains, устанавливаемых на ноду по умолчанию.

## ClusterConfiguration

[Документация](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ClusterConfiguration).

Основные параметры, на которые следует обратить внимание.

```yaml
certificatesDir: /etc/kubernetes/pki
clusterName: cluster.local
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: "registry.k8s.io"
apiServer:
  extraArgs:
    service-cluster-ip-range: "10.233.0.0/18"
    service-node-port-range: 30000-32767
kubernetesVersion: "1.25.4"
controlPlaneEndpoint: 192.168.218.189:7443
networking:
  dnsDomain: cluster.local
  podSubnet: "10.233.64.0/18"
  serviceSubnet: "10.233.0.0/18"
```

* **certificatesDir** - тут будут храниться сертификаты.
* **clusterName** - имя кластера. Все по умолчанию называют его `cluster.local`, но вы можете изменить эту традицию. 
* **etcd** - определяем параметры etcd сервера. Мы будем использовать локальный `local` сервер, установленный на
  наших control нодах. Но можно определить подключение к внешнему `external` etcd кластер.
  * **dataDir** - директория, где будут находиться файлы etcd сервера.
  * **ImageMeta** - параметры, при помощи которых можно указать какой контейнер использовать. Мы их явно не определяем, 
    потому что `imageRepository` указан на первом уровне этого конфига. И пофакту будет использоваться он. А если явно
    определить `imageTag`, то при апгрейде kubernetes на новую версию, версия контейнера etcd не изменится. 
    * **imageRepository**
    * **imageTag**
* **imageRepository** - определяем репозиторий из которого будут скачиваться образы контейнеров. Значение зависит от 
  версии kubernetes, которую вы собираетесь использовать:
  * k8s.gcr.io - для 1.24
  * registry.k8s.io - для 1.25
  * свой собственный - если кластер будет устанавливаться в закрытом ИБ периметре :).
* **apiServer** - дополнительный конфигурационные параметры API сервера.
  * **extraArgs.service-cluster-ip-range** - сеть, в которой будет выдаваться IP адреса для services кластера kubernetes.
  * **extraArgs.service-node-port-range** - номера портов для сервисов типа NodePort будут барться из указанного 
    диапазона.
* **kubernetesVersion** - версия кластера kubernetes.
* **controlPlaneEndpoint** - IP адрес или DNS имя + порт. Если не определён, будут использоваться параметры из
  `InitConfiguration` - `localAPIEndpoint.advertiseAddress`:`localAPIEndpoint.bindPort`. Если в кластере есть 
  несколько control нод, рекомендуется указывать IP адрес внешнего балансировщика.
* **networking** - конфигурация сети кластера.
  * **dnsDomain** - имя DNS домена кластера. Значение по умолчанию `cluster.local`.
  * **podSubnet** - сеть, используемая для подов кластера.
  * **serviceSubnet** - сеть, используемая для сервисов кластера. Имеется в виду `kind: Service`.

## KubeProxyConfiguration

[Документация](https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/).

Основные параметры, на которые следует обратить внимание.

```yaml
clusterCIDR: "10.233.64.0/18"
mode: ipvs
ipvs:
  strictARP: True
```

* **clusterCIDR** - сеть, используемая для подов кластера. _Тут я немного не в теме, поэтому на всякий случай определяю
  этот параметр_.
* **mode** - определяет какой механизм будет использоваться для прокси (_реализация сервисов_). Рекомендуется 
  использовать `ipvs`, как самый быстрый и масштабируемый режим.
* **ipvs** - Параметры конфигурации режима ipvs.
  * **strictARP** - настраивает параметры [arp_ignore и arp_announce](https://russianblogs.com/article/1259881483/),  
    что бы избежать ответов на запросы ARP из интерфейса `kube-ipvs0` (специальный, используемый для работы сервисов). 
    Для нормальной работы metallb, который я планирую использовать в дальнейшем, этот парметр необходимо включить.

## KubeletConfiguration

[Документация](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/).

Основные параметры, на которые следует обратить внимание.

```yaml
clusterDNS:
- 169.254.25.10
systemReserved:
  memory: 512Mi
  cpu: 500m
  ephemeral-storage: 2Gi
# Default: "10Mi"
containerLogMaxSize: 1Mi
# Default: 5
containerLogMaxFiles: 3
```

* **clusterDNS** - определяем IP адреса DNS серверов кластера. В дальнейшем я планирую для уменьшения сетевого
  трафика использовать local node dns (кеширующие DNS сервера на каждой ноде кластера). Поскольку на каждой ноде будет
  один и тот же IP адрес, беру его из [специальной сети](https://ru.wikipedia.org/wiki/Link-local_address).
* **systemReserved** - резервируем ресурсы для приложений работающих не под управлением kubernetes.
* **containerLogMaxSize** - определяем максимальный размер файла журнала контейнера до его ротации.
* **containerLogMaxFiles** - максимальный размер журнального файла контейнера.