# Calico Network Polices

[Документация](https://docs.tigera.io/calico/latest/network-policy/).

## Особенности сетевых политик calico

* Политики могут быть применены к следующему типу конечных точек (endpoints): под, контейнер, виртуальная машина,
  сетевой интерфейс хоста.
* Политики могут определять правила, которые применяются к Ingress, Egress или обеим одновременно.
* Поддерживается приоритет политик.
* Правила политик поддерживают:
  * **Действия**: allow, deny, log, pass
  * **Критерии отбора source и destination**:
    * Порт: номер порта, диапазон портов, kubernetes имена портов.
    * Протоколы: TCP, UDP, ICMP, SCTP, UDPlite, ICMPv6, протокол по его номеру (1-255).
    * Атрибуты HTTP (при использовании Istio).
    * Атрибуты ICMP.
    * Версию IP - 4 или 6.
    * IP или CIDR.
    * Endpoint selectors (на базе kubernetes labels).
    * Namespace selectors.
    * Service account selectors.
* **Дополнительные элементы управления обработкой пакетов** (*подробнее будет рассказано в одном из следующих видео*):
  * отключение connection tracking, 
  * применение перед DNAT,
  * применение к переадресованному трафику (forwarded traffic) и/или локально завершенному трафику (locally terminated 
    traffic).

## calicoctl

Для управления сетевыми политиками calico рекомендуется использовать утилиту `calicoctl`.

Смотрите какая версия calico установлена в вашем кластере и скачиваете `calicoctl` соответствующей версии:

```shell
curl -Os -L https://github.com/projectcalico/calico/releases/download/v3.25.0/calicoctl-linux-amd64
mv calicoctl-linux-amd64 calicoctl
chmod +x calicoctl
sudo mv -f calicoctl /usr/local/bin
calicoctl version
```

Для мака на М1:

```shell
curl -Os -L https://github.com/projectcalico/calico/releases/download/v3.25.0/calicoctl-darwin-arm64
mv calicoctl-darwin-arm64 calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/calicoctl
calicoctl version
```

Почти со всеми объектами calico можно работать при помощи `kubectl`. Правда не так удобно как с `calicoctl`. Для этого в 
системе должен быт установлен calico APIServer. Если calico был установлен при помощи оператора, APIServer включается
автоматически.

```shell
kubectl get tigerastatus apiserver
```

Если оператор не включен, достаточно добавить его в систему при помощи следующего манифеста:

```yaml
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
```

`calicoctl` по-прежнему требуется для следующих подкоманд:

* calicoctl node
* calicoctl ipam
* calicoctl convert
* calicoctl version

## Тестовый стенд

Тестовый стенд достался от предыдущего видео.

Для начала попробуем создать сетевые политики из предыдущего видео при помощи политик calico.

## Deny All

```yaml
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: app2
spec:
  selector: all()
  types:
    - Ingress
```

```shell
calicoctl apply -f np/np-01.yaml
```

```shell
calicoctl get networkPolicy -n app2
```

Проверяем работу приложений.

```shell
curl -s http://example.kryukov.local/app2 | jq
```

Политика сработала, получаем сообщение об ошибке.

## Разрешение подключения из namespace

```yaml
kind: NetworkPolicy
apiVersion: projectcalico.org/v3
metadata:
  name: allow-from-ns-app1
  namespace: app2
spec:
  types:
    - Ingress
  selector: 'app.kubernetes.io/instance == "app2"'
  ingress:
    - action: Allow
      protocol: TCP
      destination: {} # Не обязательно. Это значение по умолчанию.
      source:
        namespaceSelector: 'kubernetes.io/metadata.name == "app1"'
        selector: 'app.kubernetes.io/instance == "app1"'
```

*[Синтаксис выражений, используемых в `selector`](https://docs.tigera.io/calico/latest/reference/resources/networkpolicy#selectors)*

```shell
calicoctl apply -f np/np-02.yaml
```

Проверяем доступы:

```shell
curl -s http://example.kryukov.local/app2 | jq
```

Запустим приложение в namespace default:

```shell
kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools
```

Пошлем запрос к приложению app2:

> curl -s http://app1-uniproxy.app1.svc

Потом к nginx.

> curl -s http://nginx.app2.svc --connect-timeout 5

Поскольку соединение закрыто, получаем сообщение `Connection timed out`.

Удалим политику Deny для namespace app2.

```shell
calicoctl delete -f np/np-01.yaml
```

Повторим попытку доступа к app2 из пода в namespace default:

> curl http://app2-uniproxy.app2.svc --connect-timeout 5

Теперь к nginx:

> curl -s http://nginx.app2.svc 

По аналогии со стандартными сетевыми политиками kubernetes: Если к поду подключена какая-либо сетевая политика, доступ к
нему становится по умолчанию: "всё запрещено, разрешено только то, что разрешено".

## Видео

* [VK](https://vk.com/video7111833_456239249)
* [Telegramm](https://t.me/arturkryukov/334)
* [Rutube](https://rutube.ru/video/e77b546ce0c360a53e13413fe6b1cf87/)
* [Zen](https://dzen.ru/video/watch/651b25f151b4a948e55c67e8)
* [Youtube](https://youtu.be/iz6IwqvHblA)