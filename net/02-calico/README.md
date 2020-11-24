# Calico

## Режимы работы

Calico поддерживает три режима:
* **Direct** - когда поды могут обращаться к другим подам кластера через обычные сетевые соединения без
использовани различных видов тунелей (инкапсуляций пакетов).
* **IP-in-IP** - используется возможность Linux: [IP in IP tunneling](https://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.tunnel.ip-ip.html)
* **VXLAN** - инкапсуляция L2 в UDP пакеты. [Virtual eXtensible Local Area Networking documentation](https://www.kernel.org/doc/Documentation/networking/vxlan.txt)

Если машины кластера находятся в одной сети, лучшим выбором будет отсутствие любых overlay. 

## Установка драйвера сети

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

Переменная определяет режим работы сети. Отключив оба режима оверлея, мы включаем Direct режим сети.

Можно заменить размер блока (маска подсети), выделяемого на ноду (Значение по умолчанию - 26):
    
    - name: CALICO_IPV4POOL_BLOCK_SIZE
      value: 25

Подробное описание параметров, используемых при конфигурации calico/node, можно посмотреть в 
[документации](https://docs.projectcalico.org/reference/node/configuration).

Установим calico.

```shell script
kubectl apply -f calico.yaml
```

### Смотрим, вникаем

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

### Установка утилиты calicoctl

calicoctl позволяет управлять параметрами сети. 

Утилиту можно поставить непосредственно в кластер kubernetes в виде отдельного пода. Или как бинарный файл
непосредственно в Linux.

**Обратите внимание на версию программы**, которую вы пытаетесь скачать! Она должна совпадать с версией установленного
драйвера.

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/02-calico/01-install-calicoctl.sh | bash
```

Создаем конфигурационный файл программы.

```shell script
curl -s https://raw.githubusercontent.com/BigKAA/youtube/master/net/02-calico/02-calicoctl.cfg -o /etc/calico/calicoctl.cfg 
```

Проверяем работу программы

    calicoctl get nodes
    calicoctl node status

### Замена механизма оверлея

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
  cidr: 192.168.180.0/24
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: Never
```

В файле заменим параметры

    ipipMode: Never -> Always

Применим полученную конфигурацию.

    calicoctl apply -f pool.yaml

Смотрим на всех нодах кластера таблицу маршрутизации.

    route -n

Пытаемся подключиться к nginx.

Снова открываем на редактирование pool.yaml изаменяем

    ipipMode: Always -> CrossSubnet

Удаляем строки:

    creationTimestamp:
    resourceVersion:
    uid: 
    
Применим полученную конфигурацию.

    calicoctl apply -f pool.yaml

Смотрим на всех нодах кластера таблицу маршрутизации. Делаем выводы.

## Calico IPAM

Kubernetes использует плагины IPAM (IP Adress Management) для выделения IP адресов подам. Проект calico
предоставляет модуль: calico-ipam.

Модуль calico-ipam использует Calico IP pool для определения каким образом выделять IP адреса для подов в кластере.

    calicoctl get ippool

По умолчанию используется один IP pool для всего кластера. Но его можно разделить на несколько пулов. В дальнейшем
эти пулы можно назначать на под используя различные условия выбора: 

* node selectos,
* аннотаций к namespaces,
* аннотаций к подам.

Calico разделяет пулы на меньшие по размеру блоки, которые прикрепляются к node. Мы уже видели эти блоки, когда
смотрели таблицу маршрутизации ноды. К каждой ноде кластера может быть подключен один или несколько таких блоков.
Calico будет самостоятельно добавлять и удалять их.

По умолчанию размер блока соответствует подсети /26 (64 адреса). Этот параметр можно изменить как в процессе 
установки calico, так и во время обычной работы кластера.

    calicoctl get ippool default-ipv4-ippool -o yaml
    calicoctl ipam show

### Назначение пула IP адресов

Существует несколько вариантов назначения пула IP адресов. Мы посмотрим наиболее часто используемый при создании
территориально распределенных кластеров.

Предположим, что первые две ноды нашего кластера расположены в одном датацентре, а третья в другом. Сеть подов
кластера: 192.168.180.0/24

Необходимо, что бы первые две ноды были в подсети 192.168.200.0/24, а третья в 192.168.201.0/24

Нам потребуется выполнить следующие действия:
* Поставить метки на ноды кластера.
* Создать два IP пула, с определением нод кластера, на какие они будут применяться.
* Перевод пула default-ipv4-ippool в состяние disabled.
* Удалить (перезапустить) поды, что бы они при создании получили IP адреса из новых пулов.
* Удалить пул default-ipv4-ippool.

Ставим метки на ноды кластера:

    kubectl label nodes ip-218-161 location=datacenter1
    kubectl label nodes ip-218-162 location=datacenter1
    kubectl label nodes ip-174-163.kryukov.local location=datacenter2
    kubectl get nodes --show-labels

Создаём два пула:

```yaml
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
   name: datacenter1
spec:
   cidr: 192.168.200.0/24
   ipipMode: CrossSubnet
   natOutgoing: true
   nodeSelector: location == "datacenter1"
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
   name: datacenter2
spec:
   cidr: 192.168.201.0/24
   ipipMode: CrossSubnet
   natOutgoing: true
   nodeSelector: location == "datacenter2"
```

    calicoctl apply -f pool-locations.yaml
    calicoctl get ippool
    
Переводим пул default-ipv4-ippool в состяние disabled.

    calicoctl get ippool default-ipv4-ippool -o yaml > pool.yaml
    vim pool.yaml

Удаляем строки:

    creationTimestamp:
    resourceVersion:
    uid: 

Добавляем:

    disabled: true
    
Получается файл следующего содержимого:

```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  blockSize: 26
  cidr: 192.168.180.0/24
  ipipMode: CrossSubnet
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: Never
  disabled: true
```

Применяем конфиг.

    calicoctl apply -f pool.yaml
    calicoctl get ippool -o wide
    
Смотрим какие поды работают на старых ip в сети:

    kubectl get pods --all-namespaces -o wide | grep 192.168.180

Удаляем их.

    kubectl -n kube-system rollout restart deployment/calico-kube-controllers
    kubectl -n kube-system rollout restart deployment.apps/coredns
    kubectl delete pod/nginx

Запускаем nginx на третей ноде:

    kubectl run --image=nginx:latest nginx \
        --overrides='{"apiVersion": "v1", "spec": {"nodeSelector": { "kubernetes.io/hostname": "ip-174-163.kryukov.local" }}}'

Смотрим что получилось.

    kubectl get pods -o wide --all-namespaces | grep -E '192.168.200|192.168.201'
    route -n
    
Удаляем пул.

    calicoctl delete pool default-ipv4-ippool
    calicoctl get ippool
    route -n

## Заключение

Мы рассмотрели пример установки calico для кластера до 50-ти нод. Поэтому я упустил вопросы связанные с 
настройкой BGP. Но радует то, что на [сайте у calico](https://docs.projectcalico.org/about/about-calico) 
превосходно написанная документация и эти вопросы можно найти там.  