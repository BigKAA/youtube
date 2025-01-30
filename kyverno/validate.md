# Validate rules

## Запуск приложения в контейнере с правами пользователя root

Что бы запретить выполнение приложения в контейнере с правами пользователя root, в контейнере необходимо добавить `securityContext.runAsNonRoot: true` или `securityContext.runAsUser: НЕ_0`.

По идее, devops должен знать, с правами какого пользователя будет выполняться приложение в контейнере. По этому лучше использовать вариант `securityContext.runAsUser`.

Предположим, что пользователи могут деплоить приложения только в определенных namespaces:

- default
- user1
- user2

Создавать отдельную политику для каждого namespace не удобно. Поэтому создадим `ClusterPolicy`. За основу возьмём готовую политику с сайта [kyverno.io](https://kyverno.io/policies/pod-security/restricted/require-run-as-non-root-user/require-run-as-non-root-user/). Там есть много готовых политик. Но большинство из них предполагают только аудит (`validationFailureAction: audit`). Что не плохо для исследования работы вашего кластера.

Мы поправим политику под свои нужды. Поменяем название и описание.

Изменим `validationFailureAction` с `audit` на `enforce`. Что бы политика блокировала попытки деплоя манифестов.

### run-as-non-root-user

#### match

В разделе `match` определим:

- `resources.kinds`: `Pod` - будем учитывать только манифесты типа Pod. Учтите, что к ним относятся
разделы `spec.template` у манифестов `Deployment`, `StatefulSet`, `DaemonSet` и `ReplicaSet`.
- `resources.namespaces`: `default`, `user1`, `user2` - явно определяем namespaces, в которых будет работать правило.
- `resources.operations`: `CREATE`, `UPDATE` - если не 
определить этот параметр, то указанные значения - это значения по умолчанию. Но в качестве примера, мы явно указываем параметр и его значения по умолчанию.

#### validate

`validate:` - мы явно указываем, что политика будет проверять манифесты.

- `message` - сообщение, которое будет выдано в случае нарушения.
- `pattern` - шаблон, что мы будем проверять.

Разберемся с шаблоном.

Тут указывается часть манифеста пода, которую мы хотим проверять. В частности, раздел `spec`.

В нём нас интересуют следующие поля:

- `spec.securityContext`
- `spec.containers[*].securityContext`
- `spec.initContainers[*].securityContext`
- `spec.ephemeralContainers[*].securityContext`

В которых должен быть определен параметр `runAsUser`. Именно наличие этого параметра и его значение мы хотим контролировать.

С контролем значения все "прозрачно" - оно должно быть больше 0. Мы так и пишем: `">0"`. _Про операторы сравнения можно прочитать на [сайте проекта kyverno](https://kyverno.io/docs/writing-policies/validate/#operators)_

Дальше необходимо разобраться с якорями (конструкции с круглыми скобками).

`=()` - если соответствие якорю найдено в манифесте, будем проверять дальнейшее вложение:

Например:

```yaml
        pattern:
          spec:
            =(containers):
            - securityContext:
                runAsGroup: ">0"
```

__Если__ в манифесте определён параметр `spec.containers` - будем дальше смотреть массив контейнеров. В определении контейнеров __обязан присутствовать__ `securityContext`, в котом __обязательно должен__ быть определен параметр `runAsGroup`, значение которого __должно__ быть больше нуля: `>0`

Подробно про якоря написано [на сейте проекта kyverno](https://kyverno.io/docs/writing-policies/validate/#anchors).

В политике добавим аналогичное правило, но проверяющее наличие параметра `runAsGroup`.

Добавим политику:

```shell
kubectl apply -f polices/01-non-root.yaml
```

Попробуем запустить тестовое приложение:

```shell
kubectl apply -f manifests/user-manifests/01-test-app.yaml
```

В результате получим сообщение об ошибке:

```txt
Resource: "apps/v1, Resource=deployments", GroupVersionKind: "apps/v1, Kind=Deployment"
Name: "test-hostpath", Namespace: "default"
for: "manifests/user-manifests/01-test-app.yaml": error when patching "manifests/user-manifests/01-test-app.yaml": admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Deployment/default/test-hostpath was blocked due to the following policies 

require-run-as-non-root:
  autogen-run-as-non-root-group: 'validation error: Running as root is not allowed.
    The fields spec.securityContext.runAsGroup, spec.containers[*].securityContext.runAsGroup,
    spec.initContainers[*].securityContext.runAsGroup, and spec.ephemeralContainers[*].securityContext.runAsGroup
    must be set to a number greater than zero. rule autogen-run-as-non-root-group
    failed at path /spec/template/spec/containers/0/securityContext/'
  autogen-run-as-non-root-user: 'validation error: Running as root is not allowed.
    The fields spec.securityContext.runAsUser, spec.containers[*].securityContext.runAsUser,
    spec.initContainers[*].securityContext.runAsUser, and spec.ephemeralContainers[*].securityContext.runAsUser
    must be set to a number greater than zero. rule autogen-run-as-non-root-user failed
    at path /spec/template/spec/containers/0/securityContext/'
```

Добавим в манифест Deploymnet, в шаблоне пода:

```yaml
spec:
  template:
    spec:
      containers:
      - name: alpine
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
```

И повторим попытку деплоя:

```shell
kubectl apply -f manifests/user-manifests/01-test-app.yaml
```

На это раз, приложение будет запущено.

Удалим приложение:

```shell
kubectl delete -f manifests/user-manifests/01-test-app.yaml
```

## Запрет подключения локального диска ноды к контейнеру

Подключение локального диска - это volumes типа NodePath. Т.е. нам надо запретить использовать тома этого типа в манифестах.

За основу возьмем [готовую политику с сайта проекта kyverno](https://kyverno.io/policies/pod-security/restricted/restrict-volume-types/restrict-volume-types/).

Итоговый [файл политики](polices/02-hostpath.yaml).

В дополнение к применению шаблонов для проверки ресурсов, правило проверки может отклонять запрос на основе набора условий, записанных в виде выражений. Условие отклонения (deny) - это выражение, состоящее из ключа, оператора, значения и необязательного поля сообщения. В отличие от шаблона, когда deny принимает значение true, оно блокирует ресурс. Выражения шаблона, напротив, при значении true разрешают ресурс.

_Подробнее про deny можно почитать в [документации kyverno](https://kyverno.io/docs/writing-policies/validate/#deny-rules)._

В нашем случае мы перечисляем те типа томов, которые разрешены. Все, что не разрешено - запрещено.

В поле `key` мы используем [JMESPath](https://kyverno.io/docs/writing-policies/jmespath/).
При помощи которого выбираем данные из объекта [AdmissionReview](https://kyverno.io/docs/writing-policies/jmespath/#admissionreview).

Добавляем политику:

```shell
kubectl apply -f polices/02-hostpath.yaml
```

Обратите внимание на то, что сейчас в манифесте Deployment используется том типа hostPath.

Деплоим приложение:

```shell
kubectl apply -f manifests/user-manifests/01-test-app.yaml
```

Ожидаемо, получаем сообщение об ошибке:

```txt
Error from server: error when creating "manifests/user-manifests/01-test-app.yaml": admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Deployment/default/test-hostpath was blocked due to the following policies 

disable-host-path-volumes:
  autogen-restricted-volumes: 'Only the following types of volumes may be used: configMap,
    csi, downwardAPI, emptyDir, ephemeral, persistentVolumeClaim, projected, and secret.
```

Заменим тип на emptyDir и снова задеплоим приложение:

```shell
kubectl apply -f manifests/user-manifests/01-test-app.yaml
```

В этот раз все прошло нормально.

__Учтите, что кроме томов типа hostPath__, получить доступ к локальным дискам можно при помощи томов типа [local](https://kubernetes.io/docs/concepts/storage/volumes/#local). Доступ к таким томам возможен только при помощи PersistentVolume создаваемых статически. Т.е. для их создания нельзя использовать PersistentVolumeClaim. Что облегчает написание соответствующей политики kyverno. Попробуйте самостоятельно написать политику для этого типа PersistentVolume.

---
[README.md](README.md) | [usage](usage.md)
