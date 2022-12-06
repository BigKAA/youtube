# Первая control нода

После того как мы подготовили сервера, запустили необходимые сервисы, следует настроить первую control ноду
кластера.

Для начала нам необходимо понять, какие версии api поддерживает установленная версия kubeadm.

```shell
kubeadm config print init-defaults | grep apiVersion
```

Учтите, что в дальнейших примерах будут приведены примеры для следующих версий api:

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
bootstrapTokens:
- groups:
  ttl: 24h0m0s
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

* **bootstrapTokens.groups[0].ttl** - Время жизни токена. После инициализации первой ноды, kubeadm выведет на стандартный
  вывод команды для подключения остальных нод кластера. В этих командах будет использован токен. Необходимо учесть,
  что срок жизни этого токена 24 часа. Если, например через сутки, потребуется добавить новые ноды в кластер, придётся
  генерировать новый токен.
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
что бы избежать ответов на запросы ARP из интерфейса `kube-ipvs0` (специальный интерфейс, используемый для работы 
сервисов). Для нормальной работы metallb, который я планирую использовать в дальнейшем, этот парметр необходимо включить.

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

## Инициализация первой ноды

```shell
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
```

Если приложение долго не завершает свою работу, значит что-то пошло не так. Необходимо отменить все действия и запустить
его ещё раз, но с большим уровнем отладки.

 ```shell
 kubeadm reset
 kubeadm init --config /etc/kubernetes/kubeadm-config.yaml -v5
 ```

Если нода установилась нормально, добавим конфиг kubectl. И посмотрим, всё ли действительно у нас нормально.

```shell
mkdir -p $HOME/.kube
ln -s /etc/kubernetes/admin.conf $HOME/.kube/config
```

Я предпочитаю делать символьную ссылку. Но, если вы обыкновенный пользователь, можно файл скопировать.

Кстати, посмотрите какой IP адрес анонсирует кластер для доступа к своему API:

```shell
kubectl cluster-info
```

Убедимся, что нода в кластере.

```shell
kubectl get nodes
```

Убедимся, что на самом деле ничего не работает.

```shell
kubectl get pods -A
```

Потому что у нас не работает DNS и внутренняя сеть кластера.

Добавим удобства в работе с kubectl, автодополнение. _Данная фишка будет работать только с bash._

```shell
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

## nodelocaldns

Для нормальной работы нам необходимо установить кеширующий DNS сервер.

Сначала узнаем IP адрес основного DNS сервера кластера. Он нам понадобится на следующем шаге. 

```shell
kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}'
```

Подставим его в фале [манифеста](manifests/nodelocaldns-daemonset.yaml) на 24-й, 36-й и 47-й строках. 

Мы определяем куда будут пересылаться запросы о соответствующих зонах. Обратите внимание, что при запросе к основному
DNS серверу наш сервер переходит на tcp, хотя обычно для этого используется udp трафик. "Это бжжж не спроста" (с)
Винни Пух. 

Udp не устанавливает соединение и, соответственно не может его закрыть. Количество соединений в таблице ip_conntrack 
ограничено, и в принципе возможно ее переполнение. Ну и с nat преобразованиями у udp бывают проблемы. Вобщем, 
старайтесь не использовать udp в kubernetes.

На 58-й строке мы говорим, что запросы ко всем остальным доменам будут пересылаться на DNS сервера, указанные
в файле /etc/resolve.conf сервера Linux. Если бы у нас не было кеширующего сервера, то все запросы сначала шли внутри 
сети кубера на основной DNS сервера, а потом уходили на внешние серевера DNS. Немного трафика внутри кубера сэкономили.   

Скопируем файл манифеста на первую ноду кластера в  `/etc/kubernetes/nodelocaldns-daemonset.yaml`. И запустим 
приложение.

```shell
kubectl apply -f /etc/kubernetes/nodelocaldns-daemonset.yaml
```

Обратите внимание на 23-ю строку: `hostNetwork: true`. Это значит что контейнер будет открывать порт на прослушивание на 
сетевых интерфейсах хоста.

```shell
 ss -nltp | grep :53
```

Поскольку мы использовали DaemonSet, кеширующий DNS сервер будет автоматически запускаться на всех нодах кластера. 

## CNI plugin (Драйвер сети)

Я привык к calico. Но вы можете поставить [любой другой](https://github.com/containernetworking/cni#3rd-party-plugins).

Будем ставить при помощи оператора. Сначала сам опреатор:

```shell
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.5/manifests/tigera-operator.yaml
```

Пока в системе устанавливаются CRD calico. Подготовим [манифест для оператора](manifests/calico-install.yaml).

В 14-й и 15-й строках укажите параметры вашей сети.

* **cidr** - сеть, используемую для подов кластера. (_Сетью для сервисов будет управлять kube-proxy_)
* **encapsulation** - режим энкапсуляции трафика. Возможные варианты: IPIP, VXLAN, IPIPCrossSubnet, VXLANCrossSubnet, None.
  Я предпочитаю использовать IPIP или IPIPCrossSubnet. Несмотря на то, что это энкапсуляция IP в IP, а не Ethernet в
  в IP (вариант VXLAN*). C VXLAN могут быть сюрпризы.

Скопируйте файл в `/etc/kubernetes/calico-install.yaml`. И примените манифест.

```shell
kubectl apply -f /etc/kubernetes/calico-install.yaml
```

Проверяем, что все поды запустились.

```shell
watch kubectl get pods -A
```

## Немного автоматизации

Ansible [install-1st-control.yaml](https://github.com/BigKAA/00-kube-ansible/blob/main/services/install-1st-control.yaml)