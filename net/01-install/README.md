# Установка кластера.

Да, мы опять ставим кластер. Но на сей раз сделаем "упор" на сети. В качестве основной сети будем использовать
[Project calico](https://www.projectcalico.org/).

Кластер будет устанавливаться на машины с CentOS 8.

## Подготовка.

На всех машинах кластера отключаем:
* swap.
* SELinux.
* Firewall.

### Устанавливаем докер

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/01-install/00-install-docker-ce8.sh | bash
docker version
```

### Установка кубернетес

#### Установка пакетов

##### Мастер нода

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/01-install/01-install-k8s-masternode-ce8.sh | bash
```

##### Worker ноды

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/01-install/02-install-k8s-workernode-ce8.sh | bash
```

#### Мастер нода.

Создаём конфигурационный файл для установки кластера.

```yaml
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
clusterName: cluster.local
dns:
  type: CoreDNS
networking:
  dnsDomain: cluster.local
  podSubnet: 192.168.180.0/24
  serviceSubnet: 192.168.185.0/24
scheduler:
  extraArgs:
    bind-address: 0.0.0.0
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs # iptables
```

В файле определяем:
* Имя и название домена кластера.
* Сеть, используемую для выделения IP адресов для подов.
* Сеть, используемую для выделения IP адресов для сервисов.
* Программу, которая будет использоваться для NAT преобразований.

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/01-install/03-kube-config.yaml -o kube-config.yaml
```

Тестовый запуск установки, ищем ошибки.

```shell script
kubeadm init --config kube-config.yaml --dry-run | less
```

Если все хорошо - устанавливаем мастер ноду.

```shell script
kubeadm init --config kube-config.yaml
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

Смотрим что получилось

```shell script
kubectl get nodes
NAME                       STATUS     ROLES    AGE     VERSION
ip-218-161.kryukov.local   NotReady   master   2m32s   v1.19.3
```

#### Worker нода

На мастер ноде получаем токен для подключения к кластеру worker ноды.

```shell script
kubeadm token create --print-join-command
```

Запускаем установку. Токены берем из вывода предыдущей команды.

```shell script
kubeadm join 192.168.218.161:6443 --token uctr1t.w80eup2o7v19r9xf \
  --discovery-token-ca-cert-hash sha256:7f141f014028fed38611479249f7a744a183bde100afe141ee937967693db739
```

Смотрим что получилось.

```shell script
kubectl get nodes
NAME                       STATUS     ROLES    AGE     VERSION
ip-174-163.kryulov.local   NotReady   <none>   2m4s    v1.19.4
ip-218-161                 NotReady   master   2m55s   v1.19.4
ip-218-162                 NotReady   <none>   2m18s   v1.19.4
```

Видим, что DNS не запустился из-за отсутствия настроенной сети внутри кластера.

Удалим все taints с узлов кластера.

    kubectl taint nodes --all node-role.kubernetes.io/master-

### Состояние сети по умолчанию.

Смотрим сетевые интерфейсы Linux машины. _Я предпочитаю использовать классические утилиты работы с сетью, поскольку
их вывод более читабелен, по сравнению с утилитой ip. Для использования этих утилит в CentOS 8 необходимо установить пакет
net-tools_

```shell script
ifconfig -a
docker0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 02:42:b4:98:6e:53  txqueuelen 0  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ens33: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.218.161  netmask 255.255.255.0  broadcast 192.168.218.255
        inet6 fe80::20c:29ff:fec2:9ef5  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:c2:9e:f5  txqueuelen 1000  (Ethernet)
        RX packets 281779  bytes 404543348 (385.8 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 86123  bytes 8976144 (8.5 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

kube-ipvs0: flags=130<BROADCAST,NOARP>  mtu 1500
        inet 192.168.185.10  netmask 255.255.255.255  broadcast 0.0.0.0
        ether 46:d6:19:03:8d:4d  txqueuelen 0  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 381808  bytes 74988368 (71.5 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 381808  bytes 74988368 (71.5 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

или

```shell script
ip a s
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:c2:9e:f5 brd ff:ff:ff:ff:ff:ff
    inet 192.168.218.161/24 brd 192.168.218.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fec2:9ef5/64 scope link
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:b4:98:6e:53 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
4: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether 46:d6:19:03:8d:4d brd ff:ff:ff:ff:ff:ff
    inet 192.168.185.10/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 192.168.185.1/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
```

Смотрим сети Linux машины.

```shell script
route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.218.1   0.0.0.0         UG    0      0        0 ens33
169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 ens33
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.174.0   192.168.218.160 255.255.255.0   UG    0      0        0 ens33
192.168.218.0   0.0.0.0         255.255.255.0   U     0      0        0 ens33
```

или 

```shell script
ip r s
default via 192.168.218.1 dev ens33
169.254.0.0/16 dev ens33 scope link metric 1002
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.174.0/24 via 192.168.218.160 dev ens33
192.168.218.0/24 dev ens33 proto kernel scope link src 192.168.218.161
```

Обратимся к докеру. Например на мастер ноде посмотрим какие сети есть в докере.

```shell script
docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
9edbbcace7d0        bridge              bridge              local
93135ec9cba0        host                host                local
3eff5edcb254        none                null                local
```

Посмотрим, подробно на каждую сеть докера.

```shell script
docker network inspect bridge
docker network inspect null
docker network inspect host
```

Исследуем сеть hosts. Посмотрим какие поды сейчас есть в кластере kubernetes. _Разумеется, в вашем кластере имена
подов будут отличаться._

```shell script
kubectl -n kube-system get pods -o wide
NAME                                 READY   STATUS    RESTARTS   AGE   IP                NODE                       NOMINATED NODE   READINESS GATES
coredns-f9fd979d6-frz7x              0/1     Pending   0          16m   <none>            <none>                     <none>           <none>
coredns-f9fd979d6-hxmwx              0/1     Pending   0          16m   <none>            <none>                     <none>           <none>
etcd-ip-218-161                      1/1     Running   0          17m   192.168.218.161   ip-218-161                 <none>           <none>
kube-apiserver-ip-218-161            1/1     Running   0          17m   192.168.218.161   ip-218-161                 <none>           <none>
kube-controller-manager-ip-218-161   1/1     Running   0          17m   192.168.218.161   ip-218-161                 <none>           <none>
kube-proxy-8z28w                     1/1     Running   0          16m   192.168.218.161   ip-218-161                 <none>           <none>
kube-proxy-drst4                     1/1     Running   0          16m   192.168.218.162   ip-218-162                 <none>           <none>
kube-proxy-rnkhq                     1/1     Running   0          16m   192.168.174.163   ip-174-163.kryulov.local   <none>           <none>
kube-scheduler-ip-218-161            1/1     Running   0          17m   192.168.218.161   ip-218-161                 <none>           <none>
```

Мы видим, что поды coredns не инициализированы. Это нормально. Они не будут работать до тех пор, пока мы не добавим
реализацию сетевого драйвера кубернетеса.

Остальные поды работают и имеют ip адреса, соответствующие ip адресам Linux машин. Посмотрим информацию о любом из из 
этих подов.

```
kubectl -n kube-system get pod kube-apiserver-ip-218-161 -o yaml | grep hostNetwork
  hostNetwork: true
```

Мы уже использовали **`hostNetwork: true`** в видео о ingress-controller, когда поды контроллера подключали напрямую к
сетевому интерфейсу Linux хоста. 
