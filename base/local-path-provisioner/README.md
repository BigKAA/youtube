# Диски

Быстродействие любых БД упирается в скорость работы дисковой подсистемы. В kubernetes принято использовать 
PV и PVC, которые являются не самым быстрым по быстродействию решением (за некоторыми исключениями). 
Быстрые диски - это обычно локальные диски серверов, для доступа к которым используется volumes типа
hostPath. С другой стороны, как нам говорят гуру ИБ: _"использование hostPath не безопасно"_. Скорее всего из-за этого 
утверждения в большинстве известных мне helm charts и операторах диски определяются только при помощи PVC.

Ещё одна специфика PVC/PV - нет привязки диска к конкретной ноде кластера kubernetes (есть исключения из этого 
утверждения). Т.е. если под переедет на другую ноду кластера, то он сможет подключить существующий PV без создания 
нового физического диска и копирования (восстановления из бекапа). 

Под капотом у PVC/PV в подавляющем большинстве случаев лежит какая-либо сетевая файловая система. Или файловая система с 
репликацией данных по сети (например [longhorn](../../longhorn)). 

В итоге нам предлагают использовать универсальное, но не самое быстрое решение. "_Не самое быстрое_" - это весьма 
условно. Для многих задач хватит быстродействия PVC/PV. Но есть задачи, где использования PVC/PV будет тормозом. И нам
придётся "выкручиваться" подставляя hostPath в чарты (пример [minio на hostPath](../../minio)).

Итого:

* В простейшем случае для volumes используем сетевую файловую систему. Например, nfs и nfs-client-provisioner. 
* Если хочется использовать локальные диски нод кластера, с репликацией и вменяемой системой управления - смотрим
  в сторону [longhorn](../../longhorn).
* Если нужна скорость - тогда используем локальные диски нод напрямую - hostPath или 
  [local-path-provisioner](https://github.com/rancher/local-path-provisioner).

## local-path-provisioner

**В local-path-provisioner:v0.0.24 ограничение по объему PV не поддерживается!**

Поскольку специалисты ИБ не очень любят hostPath. Сделаем "ход конём", "оденем" локальные диски в PVC при помощи
local-path-provisioner.

_Небольшое замечание. Раньше, для запрета использования hostPath администраторы кластера могли определять PSP.
Но, начиная с kubernetes v1.25.0 PSP переведён в статус deprecated. :( Я пока не думал как в новых кластерах
ввести ограничение на hostPath. Но скорее всего придётся пользоваться внешними инструментами, типа
[kyverno](https://kyverno.io/policies/pod-security/baseline/disallow-host-path/disallow-host-path/)._

Манифест для установки приложения [00-local-path-storage.yaml](manifests/00-local-path-storage.yaml).

Конфигурация приложения находится в файле config.json в configMap local-path-config:

```json
{
  "nodePathMap":[
    {
      "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths":["/data/local-path-provisioner"]
    }
  ]
}
```

В конфигурации по умолчанию, на всех нодах кластера, если потребуется разместить volume. Директория
этого тома будет создаваться в `/data/local-path-provisioner`. Для каждого volume отдельная директория.

В конфигурационном файле предусмотрена возможность определения параметров для конкретных серверов
кластера.

```json
{
  "nodePathMap":[
    {
      "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths":["/data/local-path-provisioner"]
    },
    {
      "node":"ws1.kryukov.local",
      "paths":["/data", "/data2"]
    },
    {
      "node":"ws2.kryukov.local",
      "paths":[]
    }
  ]
}
```

В массиве `paths`, через запятую можно указать несколько директорий. Тогда при создании нового
локального тома его корневая директория будет выбираться случайным образом.

Если массив `paths` пустой, то на этой ноде не будут использоваться локальные диски.

Для работы с provisioner необходимо определить `StorageClass`. Простейший вариант:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

Если на нодах кластера для разных приложений требуется давать различные файловые системы (точки монтирования).
Точки монтирования необходимо определить в файле `config`.

```json
{
  "nodePathMap":[
    {
      "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths":["/data/app1","/data/app2"]
    }
  ]
}
```

А так же создать отдельные `StorageClass` для каждой файловой системы, с явным указанием параметра `nodePath`.

```yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-app1
provisioner: rancher.io/local-path
parameters:
  nodePath: /data/app1
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-app2
provisioner: rancher.io/local-path
parameters:
  nodePath: /data/app2
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

## Установка local-path-provisioner

Предварительно отредактируйте файл манифеста [00-local-path-storage.yaml](manifests/00-local-path-storage.yaml).

```shell
kubectl apply -f manifests/00-local-path-storage.yaml
```

## Тестирование PVC

В файле [01-example-pvc.yaml](manifests/01-example-pvc.yaml) показан пример PVC.

Обычно в качестве локальных файловых систем нод кластера используются _не_ кластерные файловые системы. Поэтому в PVC
указываем `accessModes` `ReadWriteOnce`.

Добавляем PVC в кластер.

```shell
kubectl apply -f manifests/01-example-pvc.yaml
```

Проверяем состояние PVC.

```shell
kubectl get pvc
```

```
NAME              STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
volume-test-pvc   Pending                                      local-path     17s
```

Мы видим, что PVC находится в состоянии Pending. Он будет находиться в таком состоянии, пока им не воспользуется
какой-либо под. Такое поведение определено в `StorageClass` при помощи параметра 
`volumeBindingMode: WaitForFirstConsumer`.

Задеплоим простейшее приложение. В манифесте пода приложения явным образом определим ноду кластера, куда оно будет
"приземляться".

```yaml
  nodeSelector:
    kubernetes.io/hostname: ws1.kryukov.local
```

```shell
kubectl apply -f manifests/02-example-pod.yaml
```

Проверяем состояние PVC.

```shell
kubectl get pvc
```

После того как приложение начало использовать PVC, provisioner сразу создал PV.

На ноде кластера можно посмотреть содержимое директории `/data/local-path-provisioner`. В ней мы увидим поддиректорию
конкретного PVC.

Удалим приложение, не удаляя PVC

```shell
kubectl delete -f manifests/02-example-pod.yaml
```

В файле манифеста изменим имя ноды кластера, куда приземляется приложение, на другую. И снова запустим приложение.

```shell
kubectl apply -f manifests/02-example-pod.yaml
```

Посмотрим состояние приложения.

```shell
kubectl get pods
```

```
NAME          READY   STATUS    RESTARTS   AGE
volume-test   0/1     Pending   0          16s
```

Приложение находится в состоянии Pending. Это происходит потому, что PV для PVC уже выделен и находится на другой ноде.
Т.е. в дальнейшем наше приложение можно будет запускать только на ноде, где создан PV для используемого в приложении 
PVC.

Удалим приложение, не удаляя PVC

```shell
kubectl delete -f manifests/02-example-pod.yaml
```

В файле манифеста изменим имя ноды кластера, куда приземляется приложение, на ноду где находится PV. 
И снова запустим приложение.

```shell
kubectl apply -f manifests/02-example-pod.yaml
```

## Использование в StatefulSet

Как мы поняли из предыдущего примера, при использовании StorageClass связанных с local-path-provisioner мы должны
внимательно следить где будут запускаться приложения.

Самым правильным вариантом, когда нам требуется сохранять состояния приложений в файловой системе, является 
использование `StatefulSet`.

При определении StatefulSet мы должны будем учесть следующие особенности:

1. Явным образом определить ноды, на которых будут запускаться поды StatefulSet-та.
2. Позаботиться о том, что бы на одной ноде запускался один под StatefulSet-та.

Пример манифеста StatefulSet [03-sts.yaml](manifests/03-sts.yaml). В нём при помощи `affinity` определяются 
соответствующие условия размещения приложения.

```yaml
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - ws3.kryukov.local
                      - ws4.kryukov.local
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - test-sts
              topologyKey: "kubernetes.io/hostname"
```

Так же, особенностью StatefulSet-та является возможность непосредственно в манифесте указать `volumeClaimTemplates`.

```yaml
  volumeClaimTemplates:
    - spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: local-path
        resources:
          requests:
            storage: 200Mi
      metadata:
        name: sts-volume
```

Задеплоим StatefulSet.

```shell
kubectl apply -f manifests/03-sts.yaml
```

Попробуем изменить количество подов в StatefulSet

```shell
kubectl scale --replicas=1 sts/sts-volume-test
kubectl get pods
```

```shell
kubectl scale --replicas=3 sts/sts-volume-test
kubectl get pods
```

```shell
kubectl scale --replicas=2 sts/sts-volume-test
kubectl get pods
```

Посмотрите список PVC. Удалите не нужные.

## Видео

* [VK](https://vk.com/video7111833_456239237)
* [Telegramm](https://t.me/arturkryukov/210)
* [Rutube](https://rutube.ru/video/c87df7cf86fd25e273fdf9e17885ab30/)
* [Youtube](https://youtu.be/9H0Wp1Xnbf4)