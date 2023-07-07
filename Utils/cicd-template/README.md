# cicd-template

Используется для генерации манифестов или values файлов helm charts.

```shell
cicd-template -in cicd-values.yaml -template values.template
```

```shell
CGO_ENABLED=0 go build
```

Приложение читает заранее определенные данные из файла данных `cicd-values.yaml`. Читает файл шаблона `values.template`.
Подставляет секции из файла данных в файл шаблона. Результат выводит на стандартный вывод.

Обязательные поля в файле данных:

* description
* image
* fullnameOverride
* resources
* readinessProbe
* livenessProbe

Пример файла с данными:

```yaml
# Файл описания приложения
description: "Тестовое приложение" # <- обязательное поле
iamge: ""
fullnameOverride: ""
resources: # <- обязательное поле
  limits:
    cpu: "0.5"
    memory: "500Mi"
  requests:
    cpu: "0.2"
    memory: "200Mi"
readinessProbe: # <- обязательное поле
  httpGet:
    port: 3000
    path: /ping
    scheme: HTTP
  initialDelaySeconds: 5
  periodSeconds: 3
livenessProbe: # <- обязательное поле
  httpGet:
    port: 3000
    path: /
    scheme: HTTP
  initialDelaySeconds: 10
  periodSeconds: 3
```

Пример файла шаблона:

```txt
description:
{{ .Description | indent 2 }}
resources:
{{ .Resources | indent 2 }}
readinessProbe:
{{ .ReadinessProbe | indent 2 }}
livenessProbe:
{{ .LivenessProbe | indent 2 }}
```

Результат работы программы выводится на стандартный вывод:

```yaml
description:
  Тестовое приложение
  
resources:
  limits:
      cpu: "0.5"
      memory: 500Mi
  requests:
      cpu: "0.2"
      memory: 200Mi
  
readinessProbe:
  httpGet:
      path: /ping
      port: 3000
      scheme: HTTP
  initialDelaySeconds: 5
  periodSeconds: 3
  
livenessProbe:
  httpGet:
      path: /
      port: 3000
      scheme: HTTP
  initialDelaySeconds: 10
  periodSeconds: 3
```
