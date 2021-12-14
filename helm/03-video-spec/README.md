# Видео три

Продолжаем создавать свой чарт для приложения. 

## Раздел spec deployment.

В values.yaml переносим replicaCount в раздел application и добавим
revisionHistoryLimit

```yaml
application:
  reloader: false
  replicaCount: 1
  revisionHistoryLimit: 3
```

В шаблоне deployment.yaml добавляем соответствующие шаблоны.

```yaml
spec:
  replicas: {{ .Values.application.replicaCount }}
  revisionHistoryLimit: {{ .Values.application.revisionHistoryLimit }}
```

За ним изменим раздел selector.matchLabels. Тут просто подставим
готовый именованный шаблон, при помощи которого определяем 
labels селектора подов.

Аналогичный шаблон, подставляем в разделе template.metadata.labels. 

```yaml
  selector:
    matchLabels:
      {{- include "openresty-art.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "openresty-art.selectorLabels" . | nindent 8 }}
```

### Аннотации пода.

Аннотации пода нам могут потребоваться например, для сбора метрик.
Хотя конкретно этот образ openresty такие метрики отдавать не умеет.
Но мы рассмотрим принцип добавления аннотаций.

В values.yaml переносим podAnnotations в раздел application. И
Оставляем его значение пустым. Т.е. по умолчанию аннотаций нет.

```yaml
application:
  podAnnotations: {}
```

В шаблоне deployment.yaml в template.metadata добавляем шаблон.

```yaml
template:
    metadata:
      {{- with .Values.application.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

В этом шаблоне мы применяем структуру управления with, которая
устанавливает область видимости переменных.

Когда мы пишем путь к переменным, мы его обычно начинаем с 
символа точка (вершина пространства имён). Например: 
_.Values.application.podAnnotations_. Если предполагается, 
что в указанном узле много переменных, то можно "переместить" 
точку в конец podAnnotations.

Затем при помощи toYaml перенесём все как есть в итоговый
манифест. Т.е. не будем разрешать остальные переменные и их 
значения. Просто скопируем.

Предполагается, что my-values.yaml мы будем явно описывать 
аннотации. Например, вот так:

```yaml
application:
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "80"
```

Посмотрим, что получилось.

    helm template app ./openresty-art -f my-values.yaml > app.yaml

```yaml
spec:
  replicas: 1
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: openresty-art
      app.kubernetes.io/instance: app
  template:
    metadata:
      labels:
        app.kubernetes.io/name: openresty-art
        app.kubernetes.io/instance: app
      annotations:
        prometheus.io/path: /metrics
        prometheus.io/port: "80"
        prometheus.io/scrape: "true"
```

## Спецификация контейнера.

Займёмся _spec.template.spec.containers_.

### imagePullSecrets

На всякий случай добавим возможность указать imagePullSecrets.

В values.yaml переносим в раздел application imagePullSecrets.
По умолчанию, массив пустой.

```yaml
application:
  imagePullSecrets: []
```

В шаблоне deployment.yaml добавим следующую конструкцию.

```yaml
    spec:
      {{- with .Values.application.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

При помощи with меняем область видимости. И при помощи toYaml
преобразуем все что там есть в yaml. По умолчанию у нас там 
пустой массив. Поэтому в итоговый манифест не подставиться.

Но если в my-values.yaml мы добавим указание имени сикрета,
то секция будет сформирована.

```yaml
application:
  reloader: true
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "80"
  imagePullSecrets:
    - name: pullSecretName
```

Проверим, что получилось.

    helm template app ./openresty-art -f my-values.yaml > app.yaml

```yaml
    spec:
      imagePullSecrets:
        - name: pullSecretName
```

Удалим imagePullSecrets из my-values.yaml, поскольку мы 
предполагаем использование публичного docker registry.

### Container

В первую очередь определим: name, image и imagePullPolicy.

В values.yaml добавим в раздел application значения по
умолчанию:

```yaml
application:
  image:
    repository: openresty/openresty
    tag: "centos-rpm"
    pullPolicy: IfNotPresent
```

В deployment.yaml добавим соответствующие шаблоны.

```yaml
      containers:
        - name: {{ include "openresty-art.fullname" . }}
          image: "{{ .Values.application.image.repository }}:{{ .Values.application.image.tag | default "centos-rpm" }}"
          imagePullPolicy: {{ .Values.application.image.pullPolicy }}
```

Из интересного тут только установка значения по умолчанию в шаблоне
{{ .Values.application.image.tag | default "centos-rpm" }}

Если tag не определен, будет подставлено значение "centos-rpm".

Проконтролируем правильность создания шаблона.

     helm template app ./openresty-art -f my-values.yaml > app.yaml

### Пробы

В созданном _helm create_ шаблоне пробы не обёрнуты в шаблон.
Это не хорошо. Мы должны дать возможность администратору,
устанавливающему наш чарт управлять пробами.

Поэтому в values.yaml, раздел application добавим следующие
строки:

```yaml
application:
  probe:
    readinessProbe:
      httpGet:
        path: /
        port: http
    livenessProbe:
      httpGet:
        path: /
        port: http
```

В deployment.yaml вместо определения проб:

```yaml
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.application.image.repository }}:{{ .Values.application.image.tag | default "centos-rpm" }}"
          imagePullPolicy: {{ .Values.application.image.pullPolicy }}
          ports:
            - containerPort: 80
              name: http
          {{- with .Values.application.probe }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
```

В my-values.yaml добавим немного изменённое определение проб.

```yaml
  probe:
    readinessProbe:
      httpGet:
        path: /index.html
        port: http
      initialDelaySeconds: 5
      periodSeconds: 15
    livenessProbe:
      httpGet:
        path: /index.html
        port: http
      initialDelaySeconds: 5
      periodSeconds: 15
      timeoutSeconds: 5
```

Проконтролируем правильность генерации проб.

    helm template app ./openresty-art -f my-values.yaml > app.yaml

### Ресурсы

В файле values.yaml переносим resources в раздел application.

```yaml
application:
  resources: {}
```

По умолчанию у нас нет ограничений.

В файле deployment.yaml добавим соответствующий шаблон.

```yaml
      containers:
        - name: {{ .Chart.Name }}
          {{- with .Values.application.resources }}
          resources:
            {{- toYaml . | nindent 10 }}
          {{- end }}
```

Проверим, что по умолчанию ресурсы не добавляются в манифест.

    helm template app ./openresty-art > app.yaml

Добавим в файл my-values.yaml определение ресурсов:

```yaml
application:
  resources:
    limits:
      cpu: "0.2"
      memory: "400Mi"
    requests:
      cpu: "0.1"
      memory: "200Mi"
```

Проверим, что ресурсы корректно подставляются.

На этом подготовка шаблона deployment.yaml завершена.

## Видео

[<img src="https://img.youtube.com/vi/OWJYAhMuyJg/maxresdefault.jpg" width="50%">](https://youtu.be/OWJYAhMuyJg)
