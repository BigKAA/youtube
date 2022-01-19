# Hazelcast

На примере установки hazelcast будет показано:

1. Как собирать логи приложения, если у вас нет доступа к локальной файловой системе.
2. Как пользоваться хорошо сделанными helm chart-ами.

За основу берём официальный [helm chart](https://github.com/hazelcast/charts/tree/master/stable/hazelcast).

## Теория сбора логов

Когда мы говорим о приложениях в контейнере, принято, что приложение свои логи должно 
выдавать на stdout и stderr. Дальше система эти данные помещает в файлы на той ноде,
где запущен контейнер с приложением. Если контейнер мигрирует на другую ноду, его
логи будут помещаться в файловую систему этой ноды кластера. Как собирать такие логи
было показано например [вот тут](../k8s-step-by-step/06-logs).

Но достаточно часто бывают ситуации, когда вы не можете запустить контейнер сборщика
логов с доступом к локальной файловой системе кластера kubernetes. И в этом случае у
вас не будет доступа к файлам с логами.

Решить проблему можно следующим образом:

1. Добавляем в контейнере локальный volume для логов.
2. Подключаем этот volume к приложению.
3. Настраиваем приложение, что бы оно выдавало логи и на stdout и писало их в файл в локальный volume.
4. Добавляем в под контейнер с приложением сбора логов.
5. Подключаем к новому контейнеру локальный volume с логами.

## Разбираемся с чартом.

В первую очередь читаем документацию к чарту. Если что то непонятно - смотрим шаблоны.

Обязательно сгенериуйте манифест со значениями по умолчанию, что бы понять какие volumes куда 
подключаются и какие имена имеют.

    helm repo add hazelcast https://hazelcast-charts.s3.amazonaws.com/
    helm repo update
    helm search repo hazelcast
    helm template hazelcast hazelcast/hazelcast > hazelcast-app.yaml

Начнём с файла values.yaml. Всё, что мы собираемся изменять, добавляем в файл my-values.yaml.
В файле values.yaml нас интересует всё, что касается возможности:

* Добавления контейнера.
* Изменения конфигурационных параметров.
* Конфигурационные файлы.
* Volumes.

### Конфигурация hazelcast

Для того, что бы hazelcast начал дополнительно писать логи в локальный файл, необходимо
изменить конфигурацию log4j.

Укажем дополнительный параметр при старте приложения определяющий, какой конфигурационный файл
будем использовать. И добавим содержимое этого файла в values.

```yaml
hazelcast:
    # javaOpts are additional JAVA_OPTS properties for Hazelcast member
    javaOpts: "-Dlog4j.configurationFile=/data/hazelcast/log4j2.properties"
    configurationFiles:
      log4j2.properties: |+
        appenders = console, file
        rootLogger.level=${env:LOGGING_LEVEL}
        rootLogger.appenderRefs= STDOUT, RollingFile 
        rootLogger.appenderRef.stdout.ref=STDOUT
        rootLogger.appenderRef.file.ref=RollingFile
        appender.console.type=Console
        appender.console.name=STDOUT
        appender.console.layout.type=PatternLayout
        appender.console.layout.pattern=${env:LOGGING_PATTERN}
        appender.file.type=RollingFile
        appender.file.name=RollingFile
        appender.file.fileName=${env:LOG_FILE_PATH}/${env:LOG_FILE}.log
        appender.file.filePattern=${env:LOG_FILE_PATH}/${env:LOG_FILE}-%d{yyyy-MM-dd}-%i.log.gz
        appender.file.layout.type=JsonLayout
        appender.file.layout.compact=true
        appender.file.layout.eventEol=true
        appender.file.policies.type=Policies
        appender.file.policies.time.type=TimeBasedTriggeringPolicy
        appender.file.policies.time.interval=1
        appender.file.policies.time.modulate=true
        appender.file.policies.size.type=SizeBasedTriggeringPolicy
        appender.file.policies.size.size=50MB
        appender.file.strategy.type=DefaultRolloverStrategy
        appender.file.strategy.max=3
```

Что означают все эти параметры почитайте в документации к log4j2. :)

В конфиге использованы две переменные среды окружения, которых нет в изначальном чарте: LOG_FILE_PATH и LOG_FILE.
Добавим их в предусмотренную для этого секцию файла values:

```yaml
# Additional Environment variables
  env:
    - name: LOG_FILE
      value: hazelcast
    - name: LOG_FILE_PATH
      value: /data/external
```

Включим поддержку локального volume:

```yaml
# externalVolume is the configuration for any volume mounted as '/data/external/'
  externalVolume:
    emptyDir: {}
```

### Конфигурация fluentbit

В качестве контейнера для сбора логов буду использовать fluentbit. Он маленький по размеру, но не маленький
по функционалу.

Конфигурационные файлы flunetbit добавим туда же, где находится конфиг log4j2. Добавим следующие строки сразу после 
определения конфига log4j2.properties:

```yaml
      fluent-bit.conf: |+
        @SET infsystem=razor
        @SET env=stage
        @SET suffix=fenix

        [SERVICE]
            Flush             1
            Daemon            Off
            Log_Level         info
            Parsers_File      parsers.conf
            HTTP_Server       On
            HTTP_Listen       0.0.0.0
            HTTP_Port         2020

        @INCLUDE input-kubernetes.conf
        @INCLUDE filter-kubernetes.conf
        @INCLUDE output-elasticsearch.conf
      parsers.conf: |+
        [PARSER]
            Name              podapp
            Format            json
            Time_Key          instant.nanoOfSecond
            Time_Format       %s
            Time_Keep         On
            # Command      |  Decoder | Field | Optional Action
            # =============|==================|=================
            Decode_Field_As   escaped_utf8    log    do_next
            Decode_Field_As   json       log
      input-kubernetes.conf: |+
        [INPUT]
            Name              tail
            Tag               ${infsystem}-${env}-${suffix}-${APP_NAME}.*
            Parser            podapp
            Path              ${LOG_FILE_PATH}/${LOG_FILE}.log
            DB                ${LOG_FILE_PATH}/${LOG_FILE}.log.db
            Mem_Buf_Limit     50MB
            Refresh_Interval  10
            Skip_Long_Lines   On
      filter-kubernetes.conf: |+
        [FILTER]
            Name              modify
            Match             ${infsystem}-${env}-${suffix}-${APP_NAME}.*
            set app           ${APP_NAME}
            set mamespace     ${APP_NAMESPACE}
            set host          ${APP_NODENAME}
            set pod           ${APP_POD}
      output-elasticsearch.conf: |+
        [OUTPUT]
            Name              stdout
            Match             *
            # Name              forward
            # Match             *
            # Host              ${FLUENT_ELASTICSEARCH_HOST}
            # Port              ${FLUENT_ELASTICSEARCH_PORT}
```

Так же добавляем определение дополнительного контейнера flunetbit.

```yaml
  # Sidecar containers to add to the Hazelcast statefulset's pod spec.
  sidecarContainers: 
    - name: fluent-bit
      image: fluent/fluent-bit:1.8
      env:
        - name: LOG_FILE
          value: hazelcast
        - name: LOG_FILE_PATH
          value: /data/external
        - name: APP_NAME
          value: hazelcast
        - name: APP_POD
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: APP_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: APP_NODENAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      imagePullPolicy: IfNotPresent
      ports:
        # Порты для сборщика метрик. На всякий случай.
        - name: fluentbit-http
          containerPort: 2020
          protocol: TCP
      volumeMounts:
        - name: hazelcast-storage
          mountPath: /fluent-bit/etc/
        # Диск с логами из helm чарта приложения
        - name: hazelcast-external
          mountPath: /data/external
```

Остальные параметры в values изменяйте по необходимости.

## Установка приложения

### Helm

    helm repo add hazelcast https://hazelcast-charts.s3.amazonaws.com/
    helm repo aupdate
    helm search repo hazelcast

    helm install hazelcast hazelcast/hazelcast -f my-values.yaml
    helm list

## Видео

[<img src="https://img.youtube.com/vi/XWTYGHGHIbY/maxresdefault.jpg" width="50%">](https://youtu.be/XWTYGHGHIbY)