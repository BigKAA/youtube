# Calico

## Режиы работы calico

Calico поддерживает три режима:
* **Not overlay** - когда поды могут обращаться к другим подам кластера через обычные сетевые соединения без
использовани различных видов тунелей (инкапсуляций пакетов).
* **IP-in-IP** - используется возможность Linux: [IP in IP tunneling](https://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.tunnel.ip-ip.html)
* **VXLAN** - инкапсуляция L2 в UDP пакеты. [Virtual eXtensible Local Area Networking documentation](https://www.kernel.org/doc/Documentation/networking/vxlan.txt)

Если машины кластера находятся в одной сети, лучшим выбором будет отсутсвие любых overlay. 

## Установка сети

Если вы используете NetworkManager, его необходимо настроить перед использованием Calico.

Создадим конфигурационный файл /etc/NetworkManager/conf.d/calico.conf, что бы запретить NetworkManager работать с
интерфейсами, управляемыми calico:

    [keyfile]
    unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico

Скачаем необходимые для установки файлы.

```shell script
curl -s https://docs.projectcalico.org/manifests/calico.yaml -O
```

В файле заменим

    - name: CALICO_IPV4POOL_IPIP
      value: "Always"
    # - name: CALICO_IPV4POOL_CIDR
    #   value: "192.168.0.0/16"
    
на

    - name: CALICO_IPV4POOL_IPIP
      value: "Never"
    - name: CALICO_IPV4POOL_CIDR
      value: "192.168.180.0/24"

Переменная определяет режим работы сети. Отключив оба режима овелея, мы включаем самый простой режим сети.

Можно заменить размер блока (маска подсети), выделяемого на ноду (Значение по умолчанию - 26):
    
    - name: CALICO_IPV4POOL_BLOCK_SIZE
      value: 25

Подробное описание параметров, используемых при конфигурации calico/node, можно посмотреть в 
[документации](https://docs.projectcalico.org/reference/node/configuration).

Установим calico.

```shell script
kubectl apply -f calico.yaml
```

## Смотрим, вникаем

Сначал посмотрим какие IP адреса получили поды в namespace kube-system

    watch kubectl -n kube-system get pods -o wide

Смотрим таблицы маршрутизации на всех нодах кластера

    route -n

Обращаем внимание на интерфейсы типа cali*.

Запускаем nginx на 3-ей ноде кластера.

    kubectl run --image=nginx:latest nginx \
        --overrides='{"apiVersion": "v1", "spec": {"nodeSelector": { "kubernetes.io/hostname": "ip-174-163.kryukov.local" }}}'

Смотрим, какой ip адрес был выдан поду

    kubectl get pods -o wide 

Попытаемся подключиться к ngix в этом поде.

Почему у нас ничего не получается?

## Установка утилиты calicoctl

calicoctl позволяет управлять параметрами сети. 

Утилиту можно поставить непосредственно в кластер kubernetes в виде отдельного пода. Или как бинарный файл
непосредственно в Linux.

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/02-calico/01-install_calicoctl.sh | bash
```

Создаем конфигурационный файл программы.

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/02-calico/02-calicoctl.cfg -o calicoctl.cfg 
```

Проверяем работу программы

    calicoctl get nodes
    calicoctl node status

## Замена механизма оверлея

    calicoctl get ippool default-ipv4-ippool -o yaml > pool.yaml
    vim pool.yaml

```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  creationTimestamp: "2020-11-08T17:41:07Z"
  name: default-ipv4-ippool
  resourceVersion: "2278"
  uid: 3da935c0-63ba-4c24-b63d-9f49b7549855
spec:
  blockSize: 26
  cidr: 10.233.64.0/18
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: CrossSubnet
```

В файле заменим параметры

    ipipMode: Never -> Always
    vxlanMode: CrossSubnet -> Never

Применим полученную конфигурацию.

    calicoctl apply -f pool.yaml

