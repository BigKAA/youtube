# Calico eBPF

Прежде чем продолжить, подумайте - нужно ли переходить на eBPF со стандартного kubernetes proxy и ipvs?

Pros:

- Мы получаем ускорение обработки пакетов и меньшую нагрузку на CPU при использовании сервисов kubernetes 
  (замена kubernetes proxy).
- Меньшие нагрузки на CPU и задержки при обработке правил Network Polices.
- Оптимизация service mesh.

Contras:

- Не очень простая отладка (мягко говоря).
- Не имеет смысла в небольших кластерах.
- Не имеет смысла при малом количестве Network Polices. 

## Что такое eBPF

[eBPF](https://ebpf.io/) - это технология, которая может запускать программы в привилегированном контексте, ядра 
Linux. Что значительно ускоряет обработку данных.

Для выполнения программ, написанных на специальном языке программирования, в ядре Linux запускается виртуальная машина.

Перед загрузкой программы в виртуальную машину происходит ее обязательная проверка, во время которой выполняется
статический анализ кода. Если приложение может привести к сбою, зависанию или иным образом негативно влияют на работу 
ядра - оно не будет запущено.

Нас ePBF интересует с точки зрения работы с сетевым стеком ядра. Ядро Linux позволяет почти на каждое событие в
сетевом стеке подключать функции пользователя, и передаёт в эти функции обрабатываемый пакет. Это позволит
перенести обработку NAT и Network Polices на уровень ядра.

## Calico и eBPF

Calico поддерживает три технологии для организации работы сервисов (NAT преобразования): iptables, ipvs и ePBF.

Iptables является самым медленным и не приспособленным для обработки большого количества преобразований. Поэтому его
сейчас практически не используют.

ipvs упрощает и ускоряет обработку пакетов. Добавляет специальный виртуальный сетевой интерфейс. В большинстве случаев
ipvs хватает для работы сети кластера. Но если вдруг вы почувствовали что сеть торомозит - то следующий шаг это переход 
на ePBF.

При включении ePBF от calico необходимо выключить kube-proxy, calico берет на себя функцию NAT. Переход с ipvs 
на eBPF на работающем кластере может положить кластер кубера. Поэтому - не надо переходить на eBPF на работающем 
кластере. Существует не маленькая вероятность его поломать. Поставьте рядом новый кластер и перенесите приложения на
него.

Так же необходимо посмотреть, какие 
[платформы и дистрибутивы kubernetes поддерживаются](https://docs.tigera.io/calico/latest/operations/ebpf/enabling-ebpf#supported).

### Переход на eBPF текущего кластера

Поскольку во время перехода на eBPF будет отключен kube-proxy, обязательным условием для переходя является прямое
подключение к kubernetes API. Посмотрите, что покажет вывод приложения `kubectl cluster-info`

```shell
kubectl cluster-info
```

```
Kubernetes control plane is running at https://192.168.218.171:6443
```

Calico в моем кластере был установлен при помощи оператора. Поэтому нам достаточно добавить ConfigMap.

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: tigera-operator
data:
  KUBERNETES_SERVICE_HOST: '192.168.218.171'
  KUBERNETES_SERVICE_PORT: '6443'
```

Ждем несколько минут пока рестартуют поды calico-node на всех нодах кластера.

Сконфигурируем kube-proxy так, что бы он запускался только на нодах с label `non-calico": true`.

```shell
kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'
```

В namespace kube-system будут удалены поды kube-proxy.

Включаем режим eBPF.

```shell
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"BPF"}}}'
```

Существующие соединения продолжат работать в старом режиме. Что бы все перешло на eBPF необходимо рестартануть каждую 
ноду кластера.

Убедитесь, что после рестарта ноды у нее нет виртуального интерфейса ipvs.

```shell
ip a s
```

Дальше проверяем установленные приложения. Например, у меня не доступен сервис `kubernetes.default.svc`, следовательно
кластер тупо не работает.

**И вот зачем я всё это писал?**

## Установка при помощи calico operator

Процедура описан тут: https://docs.tigera.io/calico/latest/operations/ebpf/install

У меня ничего не получилось. Поды calico-node регулярно отваливались. Посмотрев логи подов понял, что проблемы
с felix. 

```
+---------------------------+---------+----------------+---------------------+--------+
|         COMPONENT         | TIMEOUT |    LIVENESS    |      READINESS      | DETAIL |
+---------------------------+---------+----------------+---------------------+--------+
| CalculationGraph          | 30s     | reporting live | reporting ready     |        |
| FelixStartup              | -       | reporting live | reporting ready     |        |
| InternalDataplaneMainLoop | 1m30s   | reporting live | reporting non-ready |        |
```

Раз в полторы минуты под включался и обратно выключался. В поде не отрабатывала readnessProbe.

```
# calico-node -felix-ready
calico/node is not ready: felix is not ready: readiness probe reporting 503
```

Я надолго завис решая эту проблему. Но так и не понял что же там случилось. Оператор постоянно мешал в изменении 
конфигурации приложения. В очередной раз убедившись, что операторы - **это вселенский заговор**.
Я [пошел медитировать](https://youtu.be/Ta7ZiqAJD78).

## В итоге всё заработало

Слава Богу проект calico оставил возможность ставить приложение из манифестов. Такой способ установки решил проблему.

_Все дальнейшие действия и конфигурационные файлы можно найти в [этом](https://github.com/BigKAA/00-kube-ansible) 
плейбуке_.

Устанавливать calico bpf надо строго на новом кластере, в момент его первоначальной установки.

В дальнейшем нам **не** понадобится kube-proxy, поскольку все nat преобразования возьмёт на себя calico bpf. Поэтому
выключаем его установку во время инициализации мастер ноды.  

```shell
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml --skip-phases=addon/kube-proxy
```

Добавляем nodelocaldns (_почти все дальнейшие скрипты, конфигурационные файлы и пути к ним, взяты из плейбука_):

```shell
kubectl apply -f /etc/kubernetes/nodelocaldns-daemonset.yaml
```

Поскольку kube-proxy не установлен, добавим ConfigMap необходимый для дальнейшей работы calico, содержащий переменные
указывающие на точку подключения к kubernetes API.

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: kube-system
data:
  KUBERNETES_SERVICE_HOST: "192.168.218.171"
  KUBERNETES_SERVICE_PORT: "6443"
```

```shell
kubectl apply -f /etc/kubernetes/kubernetes-services-endpoint.yaml
```

Скачаем манифест calico.

```shell
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/calico-typha.yaml -o calico.yaml
```

Редактируем. Ищем `- name: CALICO_IPV4POOL_CIDR`, в `value` подставляем CIDR.

Так же ставим режим VXLAN, поскольку режим IPIP в случае BPF прироста в скорости не дает.

```yaml
            # Enable IPIP
            - name: CALICO_IPV4POOL_IPIP
              value: "Never"
            # Enable or Disable VXLAN on the default IP pool.
            - name: CALICO_IPV4POOL_VXLAN
              value: "Always"
```

Применяем манифест:

```shell
kubectl apply -f calico.yaml
```

Устанавливаем утилиту `calicoctl`:

```shell
curl -L https://github.com/projectcalico/calico/releases/download/v3.26.4/calicoctl-linux-amd64 -o calicoctl
chmod +x ./calicoctl
mv calicoctl /usr/local/bin
```

На данный момент у нас BPF ещё не включен. Включаем его, добавив параметр `bpfEnabled: true` в FelixConfiguration:

```yaml
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfLogLevel: ""
  floatingIPs: Disabled
  logSeverityScreen: Info
  reportingInterval: 0s
  bpfEnabled: true
```

```shell
calicoctl apply -f felix-configuration.yaml
```

Добавляем остальные ноды к кластеру.

Ждем когда заработают все поды в namespace `kube-system`.

```shell
watch kubectl -n kube-system get pods
```

Заходим в любой под calico-node и убеждаемся, что NAT преобразования переехали в BPF.

```shell
kubectl -n kube-system get pods | grep node
```

```shell
kubectl exec -it -n kube-system calico-node-5j8cm -- bash
```

Внутри пода выполняем команду:

```shell
calico-node -bpf nat dump
```

## Видео

* [VK](https://vk.com/video7111833_456239254)
* [Telegramm](https://t.me/arturkryukov/398)
* [Rutube](https://rutube.ru/video/e58259ca5e4bbc84ce600b83ad661232/)
* [Zen](https://dzen.ru/video/watch/657bfd90e258fd146aca4f70)
* [Youtube](https://youtu.be/aCaZEX8XY9I)