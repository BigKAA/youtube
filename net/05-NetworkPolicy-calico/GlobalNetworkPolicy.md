# GlobalNetworkPolicy

Одна из фишек сетевых политик calico - это наличие глобальных политик, правила которых распространяются на весь кластер
kubernetes: `kind: GlobalNetworkPolicy`.

## Deny All

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

```shell
kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools
```

Проверим возможность подключения к приложениям и сервисам.

> curl -s http://nginx.app2.svc --connect-timeout 5

> curl -s http://app2-uniproxy.app2.svc --connect-timeout 5

> curl -s http://app1-uniproxy.app1.svc --connect-timeout 5

> curl -vk https://kubernetes.default.svc:443 

Теперь разрешим доступы к приложениям. Предполагается, что доступным должно быть только приложение app1.

Проверим:

```shell
curl -s http://example.kryukov.local/
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
  name: allow-to-ns-app2
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
curl -s http://example.kryukov.local/ | jq
```

```shell
curl -s http://example.kryukov.local/app2 | jq
```

И тут:

```shell
curl -s http://example.kryukov.local/nginx | jq
```

Добавим политику Ingress в namespaces app2:

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

## Dev окружение

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

## Видео

* [VK](https://vk.com/video7111833_456239250)
* [Telegramm](https://t.me/arturkryukov/352)
* [Rutube](https://rutube.ru/video/26796bcc25f2318896be889b4500eda8/)
* [Zen](https://dzen.ru/video/watch/653a2d150a33be73310f254a)
* [Youtube](https://youtu.be/MeXxYrNHHVg)