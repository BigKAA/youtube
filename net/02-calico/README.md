# Calico

## Режиы работы calico

Calico поддерживает три режима:
* **Not overlay** - когда поды могут обращаться к другим подам кластера через обычные сетевые соединения без
использовани различных видов тунелей (инкапсуляций пакетов).
* **IP-in-IP** - используется возможность Linux: [IP in IP tunneling](https://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.tunnel.ip-ip.html)
* **VXLAN** - инкапсуляция L2 в UDP пакеты. [Virtual eXtensible Local Area Networking documentation](https://www.kernel.org/doc/Documentation/networking/vxlan.txt)

Если машины кластера находятся в одной сети, лучшим выбором будет отсутсвие любых overlay. 

## Установка сети

Скачаем необходимые для установки файлы.

```shell script
curl https://docs.projectcalico.org/manifests/calico.yaml -O
```

В файле заменим

    # - name: CALICO_IPV4POOL_CIDR
    #   value: "192.168.0.0/16"
    
на

    - name: CALICO_IPV4POOL_CIDR
      value: "10.100.10.0/24"

Переменная определяет режим работы сети. Отключив оба оежима овелея, мы включаем самый простой режим сети.

Установим calico.

```shell script
kubectl apply -f calico.yaml
```

## Смотрим, вникаем

Сначал посмотрим какие IP адреса получили поды в namespace kube-system

    kubectl -n kube-system get pods -o wide

Смотрим таблицы маршрутизации на обеих нодах кластера

    route -n

Обращаем внимание на интерфейсы типа cali*.

## Установка утилиты calicoctl

calicoctl позволяет управлять параметрами сети. 

Утилиту можно поставить непосредственно в кластер kubernetes в виде отдельного пода. Или как бинарный файл
непосредственно в Linux.

    curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.16.5/calicoctl
    chmod +x calicoctl
    mv calicoctl /usr/local/bin

Создлаем конфигурационный файл программы.

```shell script
mkdir /etc/calico
cp calicoctl.cfg /etc/calico/
```

Проверяем работу программы

    calicoctl get nodes
    calicoctl node status

## замена механизма оверлея

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
