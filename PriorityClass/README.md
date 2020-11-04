# Приоритет

## Теория

Приоритет в кубернетес - это не приоритет процессов в Линукс.
Приоритет в Линукс показывает, как часто процесс будет выполняться
процессором по сравнению с другими процессами в системе.

Приоритет в кубернетес показывает, кого первым выкинут из кластера,
если в кластере будут заканчиваться ресурсы.

Приоритет устанавливается на под. Это целое число, чем оно больше,
тем важнее модуль для системы.

За распределение подов по нодам кластера отвечает планировщик (scheduler).
В своей работе он учитывает приоритет подов. Если вы пытаетесь разместить
новый под, планировщик смотрит, есть ли в системе необходимые для его
размещения ресурсы. Если ресурсов нет, планровщик смотрит приоритет
запускаемого процесса и ищет в системе процессы с меньшим приоритетом. 
Если он их находит, он их удаляет. И так до тех пор, пока в систем не
появится достаточного ресурсов для запуска требуемого пода.

При деградации кластера, когда выходит из строя нода. Планировщик пытается 
восстановить поды с упавшей ноды на рабочих нодах. Если места для размещения
не хватает, планировщик начинает выключать поды с меньшим приоритетом и 
восстанавливать поды с большим приоритетом.

Например, приоритет удобно использовать, когда у вас в одном кластере 
одновременно размещаются среда разработки и продуктивная среда. В случае 
деградации кластера, подами среды разработки можно пожертвовать.

## PriorityClass

PriorityClass - это объект кластера, не привязываемый к namespace. Он
присваивает имя целочисленному значению приоритета.

Значение (value) PriorityClass может иметь любое 32-разрядное целое число, 
меньшее или равное 1 миллиарду.

Так же можно определить не обязательные поля:
* globalDefault - означает, что этот PriorityClass будет назначаться по
умолчанию для всех подов, у которых этот класс не определен.
* description - произвольное описание.
* preemptionPolicy - если этому полю присвоить значение Never, то поды с
указанным PriorityClass, при добавлении в систему не будут вытеснять модули
с меньшим приоритетом. Они будут запущены планировщиком после появления достаточных
для их запуска ресурсов. Значение по умолчанию: PreemptLowerPriority.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: Never
description: "The maximal priority on the cluster"
```

Если вы первый раз применяете PriorityClass в кластере, необходимо учитывать
следующее:
* У всех подов, созданных до введения PriorityClass приоритет равен нулю.
* При добавлении PriorityClass с globalDefault: true, у уже запущенных подов, у которых
не был явно установлен приоритет, он все равно остается равным нулю.
* При удалении PriorityClass, у подов, которых он был установлен, приоритет
не обнуляется. Числовое значение приоритета остается прежним.

Даже если вы ни разу не использовали PriorityClass, система на самом деле 
использует приоритеты в своей работе. Посмотрите какие PriorityClass уже
определены:

    # kubectl get pc
    NAME                      VALUE        GLOBAL-DEFAULT   AGE
    k8s-cluster-critical      1000000000   false            33d
    system-cluster-critical   2000000000   false            33d
    system-node-critical      2000001000   false            33d
    
    # kubectl get pc system-node-critical -o yaml

Если убрать служебную информацию, то system-node-critical будет выглядеть так:

```yaml
apiVersion: scheduling.k8s.io/v1
description: Used for system critical pods that must not be moved from their current
  node.
kind: PriorityClass
metadata:
  name: system-node-critical
value: 2000001000
```

Эти классы используются в системных подах, удалив которые вы нарушите работу
кластера. 

    # kubectl -n kube-system describe pod calico-node-n5xtv | grep Priority
    Priority:             2000001000
    Priority Class Name:  system-node-critical

    # kubectl -n kube-system describe pod kube-scheduler-node1 | grep Priority
    Priority:             2000000000
    Priority Class Name:  system-cluster-critical

Поэтому для своих PriorityClass используйте меньшие значения приоритета. 
Для пользовательских приоритетов принято устанавливать значения около 1000000.

## priorityClassName

Для указания, какой PriorityClass необходимо присвоить поду, используют параметр
priorityClassName.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: openresty
  labels:
    app: openresty
spec:
  containers:
  - name: openresty
    image: openresty:latest
    imagePullPolicy: IfNotPresent
  priorityClassName: high-priority
```
## Видео
* https://youtu.be/BGd-NsaQF7g
