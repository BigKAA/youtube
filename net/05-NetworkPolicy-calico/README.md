# Calico Network Polices

[Документация](https://docs.tigera.io/calico/latest/network-policy/).

Сетевые политики Calico добавляю в систему свой API `projectcalico.org/v3` и предоставляет более богатый набор 
возможностей политик.

Например, calico позволяет упорядочивать политики (приоритет политик). Добавляет правила запрета и более гибкие 
правила сопоставления. Вводит глобальные политики, применяемые ко всему кластеру kubernetes.

В то время как сетевая политика Kubernetes применяется только к подам, сетевая политика Calico может применяться к 
нескольким типам конечных точек, включая поды, сервисы, виртуальные машины и интерфейсы хоста. При использовании 
совместно с Istio service mesh сетевая политика Calico поддерживает защиту приложений на 5-7 уровнях.

Сетевые политики Calico можно использовать совместно со стандартными сетевыми политиками kubernetes. Например,
можно разрешить разработчикам использовать сетевые политики kubernetes. А для глобальной защиты кластера в качестве 
пограничной защиты или более высокоуровневой использовать политики calico. Разрешив редактирование этих политик
только службе ИБ или администраторам кластера. 

## Особенности сетевых политик calico

* Политики могут быть применены к следующему типу конечных точек (endpoints): под, контейнер, виртуальная машина,
  сетевой интерфейс хоста.
* Политики могут определять правила, которые применяются к Ingress, Egress или обеим одновременно.
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

Для управления сетевыми политиками calico рекомендуется использовать утилиту calicoctl.

Смотрите какая версия calico установлена в вашем кластере и скачиваете calicoctl соответствующей версии:

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

На этом пожалуй закончим повторять правила из предыдущего видео о стандартных сетевых политиках
kubernetes. Перейдём к особенностям политик calico.


## GlobalNetworkPolicy

Одна из фишек сетевых политик calico - это наличие глобальных политик, правила которых распространяются на весь кластер
kubernetes: `kind: GlobalNetworkPolicy`.

### Deny All

В качестве примера глобальной сетевой политики рассмотрим политику DenyAll. Запретим по умолчанию весь трафик.

При создании такой политики надо хорошо представлять последствия запрета. Поэтому, прежде чем что-то запрещать,
следует сесть и хорошо подумать.

Во-первых, под правила запрета не должны попадать системные приложения кластера. Обычно это приложения, находящиеся в
namespace `kube-system`. Доступ приложений к DNS серверу кластера. Из под удара должны быть выведены другие системные 
приложения, участвующие, например в сборе метрик, организации сетевого трафика и т.п.

Посмотрим список namespaces, которые есть в моем кластере:

```shell
kubectl get ns
```

    NAME                 STATUS   AGE
    app1                 Active   161m
    app2                 Active   161m
    argocd               Active   23h
    calico-apiserver     Active   153d
    calico-system        Active   153d
    cert-manager         Active   152d
    default              Active   153d
    ingress-nginx        Active   152d
    kube-node-lease      Active   153d
    kube-public          Active   153d
    kube-system          Active   153d
    lens-metrics         Active   153d
    local-path-storage   Active   152d
    metallb-system       Active   152d
    tigera-operator      Active   153d

Подавляющее большинство из представленных namespaces содержат в себе либо системные, либо вспомогательные приложения.
Ограничение трафика на которые повлечет за собой написание большого количества сетевых политик.
Большое количество сетевых политик влечет за собой следующие риски:

1. Логические ошибки в правилах. Что-то забыли, где-то указали не тот порт.
2. Сложность отладки политик.
3. Снижение скорости сети. Чем больше правил, тем больше задержка на пути прохождения сетевого пакета.

В моём случае можно ограничиться разумным минимумом:

1. При помощи правил RBAC разрешить пользователям шалить только в namespaces, где располагаются их приложения: app1 и
app2.
2. Создать глобальную политику DenyAll, затрагивающую только эти namespaces.

Заниматься перечислением в сетевой политике labels всех интересующих нас namespaces (имеется в виду перечисление по
именам) дело не благодарное. Списки могут быть слишком большие. Поэтому в качестве обязательного правила 
администрирования кластера kubernetes следует сказать, что: "все пользовательские namespaces должны быть отмечены
labels `policy: user`". *Разумеется название и значение label вы для себя выберете сами*.

```shell
kubectl label namespace app1 policy=user
kubectl label namespace app2 policy=user
kubectl label namespace default policy=user
```

Теперь напишем глобальную сетевую политику, которая будет работать только в трех namespaces, помеченных соответствующей 
меткой.

Политика должна содержать следующие правила:

* Запретить по умолчанию весь входящий и исходящий трафик.
* Разрешить исходящий трафик:
  * К nodelocaldns (напоминаю, что это особенность моего кластера).
  * К сервису `kubernetes` в namespace `default`.

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: deny-policy-user
spec:
  namespaceSelector: 'policy == "user"'
  types:
  - Ingress
  - Egress
  egress:
  - action: Allow
    protocol: UDP
    destination:
      nets:
        - 169.254.25.10/32
      ports:
      - 53
  - action: Allow
    protocol: TCP
    destination:
      nets:
        - 169.254.25.10/32
      ports:
        - 53
  - action: Allow
    destination:
      services:
        name: kubernetes
        namespace: default
```

```shell
calicoctl apply -f np/np-03.yaml
```

Проверим возможность подключения к приложениям и сервисам.

> curl -s http://nginx.app2.svc --connect-timeout 5

> curl -s http://app2-uniproxy.app2.svc --connect-timeout 5

> curl -s http://app1-uniproxy.app1.svc --connect-timeout 5

> curl -vk https://kubernetes.default.svc:443 

Теперь разрешим доступы к приложениям. Предполагается, что доступным должно быть только приложение app1.

Проверим:

```shell
curl -s http://example.kryukov.local/app2 | jq
```

```yaml
---
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: allow-to-app1
  namespace: app1
spec:
  types:
    - Ingress
  selector: 'app.kubernetes.io/instance == "app1"'
  ingress:
    - action: Allow
---
kind: NetworkPolicy
apiVersion: projectcalico.org/v3
metadata:
  name: allow-to-ns-app1
  namespace: app1
spec:
  types:
    - Egress
  selector: 'app.kubernetes.io/instance == "app1"'
  egress:
    - action: Allow
      destination:
        namespaceSelector: 'kubernetes.io/metadata.name == "app2"'
```

```shell
calicoctl apply -f np/np-04.yaml
```

Проверяем:

```shell
curl -s http://example.kryukov.local/app2 | jq
```

И тут:

```shell
curl -s http://example.kryukov.local/nginx | jq
```

Исправим политику Ingress в namespaces app2:

```yaml
kind: NetworkPolicy
apiVersion: projectcalico.org/v3
metadata:
  name: allow-to-nginx
  namespace: app2
spec:
  types:
    - Ingress
  selector: app == 'nginx'
  ingress:
    - action: Allow
      protocol: TCP
      source:
        namespaceSelector: 'kubernetes.io/metadata.name == "app1"'
```

```shell
calicoctl apply -f np/np-05.yaml
```

Еще раз проверяем.

```shell
curl -s http://example.kryukov.local/nginx | jq
```

### Dev окружение

*Удалите все политики, которые были добавлены ранее*.

```shell
calicoctl delete -f np/np-03.yaml 
calicoctl delete -f np/np-04.yaml
calicoctl delete -f np/np-05.yaml
```

Достаточно распространённая ситуация - выделение набора namespaces в кластере для разработчиков. В этом случае нам 
потребуется разрешить беспрепятственное хождение пакетов между этими namespaces, но запретить исходящий трафик.

В calico сетевые политики применяются к различным Endpoints (термин calico). Эти endpoints в политках выбираются 
стандартным для kubernetes методом - при помощи labels. Соответственно, если мы хотим в политиках использовать
endpoints, расположенные в определённых namespaces, мы должны пометить эти namespaces.

Предположим, что namespaces `app1` и `app2` выделены разработчикам. Пометим их при помощи labels:

```shell
kubectl label namespace app1 developer=company1
kubectl label namespace app2 developer=company1
```

Добавим сетевую политику:

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: access-company1
spec:
  types:
    - Ingress
    - Egress
  namespaceSelector: 'developer == "company1"'
  ingress:
    - action: Allow
      source:
        namespaceSelector: 'developer == "company1"'
  egress:
    - action: Allow
      destination:
        namespaceSelector: 'developer == "company1"'
```

Обратите внимание на то, что при ограничении исходящего трафика всегда необходимо разрешать обращение к DNS.

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: access-company1-to-dns
spec:
  types:
    - Egress
  namespaceSelector: 'developer == "company1"'
  egress:
    - action: Allow
      protocol: UDP
      destination:
        nets:
          - 169.254.25.10/32
        ports:
          - 53
    - action: Allow
      protocol: TCP
      destination:
        nets:
          - 169.254.25.10/32
        ports:
          - 53
    - action: Allow
      destination:
        services:
          name: kubernetes
          namespace: default
```

Применим политики:

```shell
calicoctl apply -f np/np-06.yaml 
```

```shell
calicoctl apply -f np/np-07.yaml 
```

Проверяем работу политики:

```shell
curl -s http://example.kryukov.local/ | jq
```

Что то пошло не так.

Запустим dnstool в namespace app1:

```shell
kubectl -n app1 run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools
```

    curl app1-uniproxy --connect-timeout 5
    curl app1-uniproxy/app2
    curl app1-uniproxy/nginx

Всё работает, но только внутри namespaces.

Надо добавить разрешение хождения из-за пределов кластера.

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: access-to-company1-from-inet
spec:
  types:
    - Ingress
  namespaceSelector: 'developer == "company1"'
  ingress:
    - action: Allow
      source:
        selector: 'app.kubernetes.io/name == "ingress-nginx"'
```

```shell
calicoctl apply -f np/np-08.yaml 
```

Что бы не "мусорить", все эти политики можно объединить в одну:

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: access-company1
spec:
  types:
    - Ingress
    - Egress
  namespaceSelector: 'developer == "company1"'
  ingress:
    - action: Allow
      source:
        namespaceSelector: 'developer == "company1"'
    - action: Allow
      source:
        selector: 'app.kubernetes.io/name == "ingress-nginx"'
  egress:
    - action: Allow
      destination:
        namespaceSelector: 'developer == "company1"'
    - action: Allow
      protocol: UDP
      destination:
        nets:
          - 169.254.25.10/32
        ports:
          - 53
    - action: Allow
      protocol: TCP
      destination:
        nets:
          - 169.254.25.10/32
        ports:
          - 53
    - action: Allow
      destination:
        services:
          name: kubernetes
          namespace: default
```

```shell
calicoctl delete -f np/np-06.yaml
calicoctl delete -f np/np-07.yaml
calicoctl delete -f np/np-08.yaml
```

```shell
calicoctl apply -f np/np-09.yaml
```