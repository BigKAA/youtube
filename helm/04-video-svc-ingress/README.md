# Видео четыре

## Service

В файле values.yaml переносим (добавляем) строки:

```yaml
service:
  # Service type: ClusterIP or NodePort
  type: ClusterIP
  port: 80
  # Если сервис типа NodePort
  nodePort: ""
  # Если необходимо, определите имя порта
  name: ""
```

Предполагается, что наш чарт будет поддерживать только 
два типа сервисов: CluserIP (по умолчанию) и NodePort.

В фале service.yaml добавляем шаблон.

```yaml
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
```

Так же нам необходимо отработать ситуацию, когда сервиса типа NodePort.
В этом случае следует определить параметр nodePort, в случае, если 
он определён. В этом нам поможет следующая конструкция:

```yaml
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
```

В качестве значения оператору if передаётся функция and. Которая проверяет
истинность двух значений:
* eq .Values.service.type "NodePort" - истина, если type равен NodePort.
* .Values.service.nodePort - истина, если значение определено.

Если оба значения истина, то будет подставлен параметр nodePort.

Так же добавим формирование имени порта:

```yaml
      {{- if .Values.service.name }}
      name: {{ .Values.service.name }}
      {{- end }}
```

Добавим в файл my-values.yaml следубщие строки:

```yaml
service:
  type: NodePort
  nodePort: 31002
  name: proxy
```

Проверим создание шаблона.

    cd helm/04-video/
    helm template app ./openresty-art/ -f my-values.yaml > app.yaml

## Ingress

C ingress поступим просто.

Сначала в values.yaml перенесем всю секцию ingress.
Так же скопируем эту секцию в my-values.yaml и немного её отредактируем.

```yaml
ingress:
  enabled: true
  className: "system-ingress"
  annotations:
    certmanager.k8s.io/cluster-issuer: monitoring-issuer
  hosts:
    - host: application.kryukov.local
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - application
      secretName: art-tls
```

А затем просто скопируем ingress-orig.yaml в директорию templates и
назовём его ingress.yaml. Т.е. просто удалим старый ingress.

Поскольку имя сервиса, относительно первоначально сгенерированного шаблона
у нас изменено, добавим несколько дополнений/изменений в файле шаблона.

После второй строки добавим переменную:

```yaml
{{- $svcName := printf "%s-%s" $fullName "svc" -}}
```

В строках номер 53 и 57 заменим $fullName на $svcName.

На этом базовые изменения в шаблоне ingress, шаблон готов к применению. 
В этом можно убедиться, создав манифест приложения.

    helm template app ./openresty-art/ -f my-values.yaml > app.yaml

Что бы разобраться в шаблоне, выпишем все используемые в нём, ещё
не известный нам функции.

* **semverCompare** - Семантическое сравнение двух строк. Два аргумента -
строки в формате версии. Позволяет сравнить версии приложений.
* **hasKey** - Возвращает истину, если данный словарь содержит данный ключ.
* **set** - Добавляет в словарь новую пару ключ/значение.

## NOTE.txt

Содержимое файла NOTE.txt выводится на стандартный вывод после установки 
или обновления чарта (helm install или helm upgrade).

## Видео

[<img src="https://img.youtube.com/vi/dwS21jD7fq0/maxresdefault.jpg" width="50%">](https://youtu.be/dwS21jD7fq0)