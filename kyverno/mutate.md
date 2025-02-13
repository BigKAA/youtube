# Mutate и generate rules

## Задача

- При создании нового namespace в проекте, копировать туда Secret с параметрами подключения к registry, с закрытым паролем доступом.
- При добавлении нового пода в этом namespace, добавлять в манифест пода соответствующие параметры доступа к закрытому registry.

В проекте пользователя будут использоваться два namespaces:  `user1` и `user2`.

## Алгоритм

1. Создадим namespace, в котором будут находится эталонные secrets. Этот namespace должен быть недоступен пользователям проекта.
2. Создадим generate политику, которая будет клонировать эталонный secret в создаваемый namespace.
3. Создадим mutate политику, которая будет добавлять в манифест размещаемого в namespaces проекта пода, параметры определяющие использования secret.

### Namespace шаблона и Secret

Создадим namespace, в котором будут находиться эталонные secrets.

```shell
kubectl create ns project-templates
```

Создадим secret с параметрами доступа к закрытому rgistry:

```shell
kubectl -n project-templates create secret docker-registry docker-registry \
  --docker-email=kyverno@kryukov.local \
  --docker-username=kyverno \
  --docker-password=aQp-dpN-h95-C2M \
  --docker-server=lunar.kryukov.biz:10443
```

### Добавление ролей

В установке по умолчанию, kyverno может модифицировать (создавать) далеко не все kind в кластере k8s.
Например, дальше мы при помощи политики kyverno будем создавать secret. По умолчанию kyverno не может работать с secret. Поэтому нам придется добавить ClusterRole, разрешающие соответствующие действия.

В kyverno используется механизм [aggregated ClusterRoles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles). Который позволяет расширять текущую роль (включать другую роль) "на лету". Т.е. для добавления новых правил RBAC достаточно создать роль с определенным label. И она автоматически будет добавлена в "родительскую" роль.

Инсталляция kyverno содержит 4 родительских роли для 4-х контроллеров. Подробно об этих ролях и как их расширять написано в [документации по kyverno](https://kyverno.io/docs/installation/customization/#customizing-permissions).

Для разрешения работы с secrets мы создадим [две роли](roles/01-secret.yaml) для background-controller и admission-controller:

```shell
kubectl apply -f roles/01-secret.yaml
```

Проверим возможности доступа:

```shell
kubectl auth can-i list secret --as system:serviceaccount:kyverno:kyverno-admission-controller
```

### Generate politic

После добавления ролей, создадим [политику](polices/03-project-copy-secret.yaml), позволяющую копировать определённый secret из конкретного namespace во вновь создаваемый namespace.

В политике, при помощи шаблона, определим namespaces к которым будет применяться политика. В нашем случае, все namespacesБ имя которых начинается с "user".

```shell
kubectl apply -f polices/03-project-copy-secret.yaml
```

Создадим два namespaces:

```shell
kubectl create ns user1
kubectl create ns user2
```

Проверим наличие secrets в namespace:

```shell
kubectl -n user1 get secrets
```

### Mutate politic

Следующий шаг - создание [политики](polices/04-project-insert-imagepoolsecret.yaml), которая будет добавлять в манифесты пода imagePullSecrets. Но не во все поды, а только в те, где image находится в определённом registry.

Попробуем установить приложение, которое использует контейнер, образ которого хранится в закрытом registry.

```shell
kubectl -n user1 apply -f manifests/user-manifests/02-test-app-srepo.yaml
```

Убедимся, что скачать образ не получается.

Удалим приложение:

```shell
kubectl -n user1 delete -f manifests/user-manifests/02-test-app-srepo.yaml
```

Добавим политику:

```shell
kubectl apply -f polices/04-project-insert-imagepoolsecret.yaml
```

Вторая попытка запуска приложения:

```shell
kubectl -n user1 apply -f manifests/user-manifests/02-test-app-srepo.yaml
```

Проверяем:

```shell
kubectl -n user1 get deployments
kubectl -n user1 get deployments test-secret -o jsonpath='{.spec.template.spec.imagePullSecrets}'
```

---
[README.md](README.md) | [usage](usage.md)
