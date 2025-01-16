# Установка

Установка kyverno при помощи helm чарта:

```shell
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

## Установка при помощи ArgoCD

### Application tracking

ArgoCD автоматически устанавливает label `app.kubernetes.io/instance` и использует ее для определения того, какие ресурсы относятся к приложению. Helm чарт Kyverno также устанавливает эту метку для тех же целей. Чтобы разрешить этот конфликт, переведите ArgoCD tracking метод с labels на annotations. Для этого, при установке чарта ArgoCD в `values.yaml` следует добавить:

```yaml
configs:
  cm:
    application.resourceTrackingMethod: annotation   
```

### Server side diff

Server side diff будет выполнять деплой приложения в режиме dryrun для каждого ресурса приложения. Затем результат этой операции сравнивается с текущим состоянием приложения в кластере kubernetes. Результаты diff кэшируются, и новые запросы Apply на стороне сервера к Kube API запускаются только тогда, когда:

- Запрашивается обновление приложения или повторное обновление.
- В репозитории, на который нацелено приложение Argo CD, добавлена новая редакция.
- Изменилась спецификация приложения Argo CD.

Одним из преимуществ серверного Diff является то, что контроллеры доступа Kubernetes (Kubernetes Admission Controllers) будут участвовать в вычислении diff. Если, например, validation webhook идентифицирует ресурс как недействительный, об этом будет сообщено Argo CD на этапе diff, а не на этапе синхронизации.

Этот функционал ArgoCD все еще находится в стадии тестирования (бета). Но считается стабильной.

Включения server side diff для всего кластера. В `values.yaml` ArgoCD добавим:

```yaml
configs:
  cm:
    controller.diff.server.side: "true"   
```

Если необходимо включать только для одного приложения, используется аннотация в kind `Application`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/compare-options: ServerSideDiff=true
```

Server side diff не учитывает изменения вносимые при помощи mutation webhooks. Если нужно включить этот функционал, в аннотациях `Application` надо добавить:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/compare-options: IncludeMutationWebhook=true
```

Это работает только при включённом server side diff.

### Ignoring RBAC changes made by AggregateRoles

Kyverno используем механизм AggregateRoles. В ArgoCD нужно включить опцию, чтобы игнорировать изменения в RBAC, которые сделаны с помощью AggregateRoles. В values.yaml ArgoCD необходимо добавить:

```yaml
configs:
  cm:
    ignoreAggregatedRoles: true
```

### Особенности установки при помощи ArgoCD

Если для установки используется ArgoCD, обязательно включайте `ServerSideApply`.

```yaml
syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Добавляем отдельный проект и helm chart:

```shell
kubectl apply -f manifests/01-kyverno-project.yaml
kubectl apply -f manifests/02-kyverno-app.yaml
```

## Тестовое приложение

Для тестов будем использовать простейший контейнер. Dockerfile:

```Dockerfile
FROM alpine:3.20.3
RUN addgroup -g 1000 -S testroup && adduser -u 1000 -S testuser -G testroup
```

Сборка образа:

```shell
docker buildx build -t lunar.kryukov.biz:10443/library/kyverno/demoapp:0.0.1 -f containers/demoapp.Dockerfile .
docker push
```

_Я не гарантирую, что контейнер `lunar.kryukov.biz:10443/library/kyverno/demoapp:0.0.1` будет доступен всегда. Рекомендую создать свой собственный контейнер и в дальнейшем использовать его._

---
[README.md](README.md)
