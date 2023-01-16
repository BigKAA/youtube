# Opentelemetry + opensearch

Поскольку в предыдущем примере, в качестве хранилища метрик мы установили opensearch.
Для отображения трейсов, вместо jaeger можно воспользоваться встроенным в opensearch
модулем Observability. Который включает в себя, в том числе и работу с трейсами.

К сожалению, он не умеет работать с данными, которые сохраняет jaeger. Поэтому придется
использовать другой набор программ для сбора трейсов: 
[opentelemetry collector](https://opentelemetry.io/docs/collector/) и
[data prepper](https://opensearch.org/docs/latest/data-prepper/index/).

Оба приложения коллекторы. Первый универсальный. Его мы будем использовать в качестве агента на каждой ноде кластера.

Второй специализированный. Он умеет сохранять данные о трейсах в формате, который понимает
модуль Observability. Мы запустим пару экземпляров (_на самом деле один_), больше не надо.

Otel collector умеет принимать на вход различные варианты протоколов. Поэтому у него мы включим протоколы, которые были
использованы в предыдущем примере. Все они входят в стандартный дистрибутив коллектора и нам не потребутся делать
доплнительные телодвижения. Так же следует учесть, что ingress controller ещё не научили пользоваться otlp и он
использует jaeger.thrift/UDP для подключения к коллектору. В приложениях application1 и 2 я буду использовать otlp. 

_Мне почему-то не удалось подружить jaeger из python библиотеки с otlp data prepper. Эти библиотеки как то не корректно
преобразуют events в спанах. Теряют его имя. И prepper отказывает принимать такие спаны. Хотя в то же время от ingress спаны
принимаются и конвертируются как надо. Но там используется реализация библиотеки на `c`. 
И тут либо что то не так с библиотекой, либо из меня тот ещё программист. Скорее всего второе, виноваты мои кривые руки._

_Поэтому приложения application1 и 2 будут подключаться по otel http._

Затем otlp collector передаёт данные по протоколу otlp-grpc на вход data prepper. Который в дальнейшем формирует
индексы в opensearch.

Создадим namespace в котором будем размещать все наши приложения.

```shell
kubectl create ns otel
```

Opensearch был уже установлен в предыдущем примере. Воспользуемся им.

## Data prepper

[Документация](https://github.com/opensearch-project/data-prepper/blob/main/docs/trace_analytics.md).

Для установки приложения будем использовать подготовленный файл манифеста [prepper.yaml](manifests/otel/prepper.yaml).

Конфигурация приложения находится в ConfigMap `data-prepper-config`. И производится при помощи определения piplines.

Первый pipeline - `entry-pipeline`

```yaml
entry-pipeline:
  delay: "100"
  source:
    otel_trace_source:
      ssl: false
  buffer:
    bounded_blocking:
      buffer_size: 10240
      batch_size: 160
  sink:
    - pipeline:
        name: "raw-pipeline"
    - pipeline:
        name: "service-map-pipeline"
```

В разделе source мы определяем как будет получать данные pipeline. В нашем примере
используется протокол otel-grpc. С отключёнными шифрованием и авторизацией.

Полученные данные буферизируются и пачками отправляются на два других pipline:
`raw-pipeline` и `service-map-pipelin`.

```yaml
raw-pipeline:
  source:
    pipeline:
      name: "entry-pipeline"
  buffer:
    bounded_blocking:
      buffer_size: 10240
      batch_size: 160
  processor:
    - otel_trace_raw:
    #- otel_trace_group:
    #    hosts: [ "https://opensearch-cluster-master.es.svc:9200" ]
    #    # Change to your credentials
    #    username: $ES_ADMIN
    #    password: $ES_PASSWORD
  sink:
    - opensearch:
        hosts: ["https://opensearch-cluster-master.es.svc:9200"]
        insecure: true
        username: $ES_ADMIN
        password: $ES_PASSWORD
        index_type: trace-analytics-raw
```

`raw-pipeline` при помощи процессора 
[otel_trace_raw](https://opensearch.org/docs/latest/data-prepper/data-prepper-reference/#otel_trace_raw)
добавляются поля, связанные с группой трассировки (трейса), необходимые для модуля Observability.

Так же можно подключить процессор `otel_trace_group`, который будет посылать запросы в opensearch для
поиска недостающей информации о группе трассировки. Но это требуется крайне редко и замедляет и так не 
быстрый механизм.

В итоге данные сохраняются в отдельном индексе в opensearch.

```yaml
service-map-pipeline:
  delay: "100"
  source:
    pipeline:
      name: "entry-pipeline"
  buffer:
    bounded_blocking:
      buffer_size: 10240
      batch_size: 160
  processor:
    - service_map_stateful:
  sink:
    - opensearch:
        hosts: ["https://opensearch-cluster-master.es.svc:9200"]
        insecure: true
        username: $ES_ADMIN
        password: $ES_PASSWORD
        index_type: trace-analytics-service-map
```

Процессор [service_map_stateful](https://opensearch.org/docs/latest/data-prepper/data-prepper-reference/#service_map_stateful) 
использует данные OpenTelemetry для создания карты распределенного сервиса для визуализации на панелях 
opensearch.

Подключится к коллектору можно по протоколу otlp-grpc при помощи сервиса `data-prepper.otel.svc:21890`.

Установим приложение.

```shell
kubectl -n otel apply -f manifests/otel/prepper.yaml
```

А это на всякий случай. Вдруг что-то пойдёт не так.

```shell
kubectl -n otel delete -f manifests/otel/prepper.yaml
```

## Opentelemetry agent

* [Collector](https://github.com/open-telemetry/opentelemetry-collector). Базовый дистрибутив.
* [Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib). Дистрибутив с модулями из 
 contrib репозитория.

Opentelemetry коллектор описан в файле [otel-agent.yaml](manifests/otel/otel-agent.yaml).

В конфигурационном файле написано много чего. Нас интересуют `receivers` и `exporters`.

В первом разделе определяется какие протоколы на каких портах принимает приложение.

```yaml
receivers:
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_compact:
        endpoint: 0.0.0.0:6831
      thrift_http:
        endpoint: 0.0.0.0:14268
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```

В `exporters` указано куда пересылать данные.

```yaml
exporters:
  otlp:
    endpoint: data-prepper:21890
    tls:
      insecure: true
```

Приложение запускаем при помощи Daemonset. Сажаем его на сетевые интерфейсы хоста `hostNetwork: true`.

На всякий случай формируем сервис. Он пригодится для приложений, в конфигурации которых не получится
указать IP адрес хоста на котором они работают.

Параметры подключения:

* Порты на хост интерфейсах воркер нод:
    * jaeger-compact - 6831/UDP
    * jaeger-grpc - 14250
    * jaeger-thrift - 14268
    * otlp-grpc - 4317
    * otlp-http - 4318
    * zipkin - 9411
* Для приложений, которым не получится подставить IP адрес хоста можно указывать сервис: 
  otel-collector-agent.otel.svc

```shell
kubectl -n otel apply -f manifests/otel/otel-agent.yaml
```

```shell
kubectl -n otel delete -f manifests/otel/otel-agent.yaml
```

## Ingress

В values файле чарта ingress контроллера определим параметры для работы с коллекторами.

```yaml
  config:
    enable-opentracing: "false"
    jaeger-collector-host: otel-collector-agent.otel.svc
    jaeger-propagation-format: w3c
```

Ингресс контроллер пока не умеет работать по протоколу otlp, поэтому в otlp коллекторе мы включили
`jaeger-compact port: 6831/UDP`. Именно к нему будет подключаться контроллер.

`enable-opentracing: "false"` - выключаем. Иначе мы будем ловить в трейсах любые запросы к инегресс
контроллеру, а не те, которые мы укажем в ingress приложений.

Меняем конфигурацию контроллера.

```shell
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -f charts/ingress-controller/my-values.yaml -n ingress-nginx
```

**Важно понимать**, что если будет недоступен коллектор, ингресс контроллер не получится перезапустить. Он будет падать 
с ошибкой! Учтите это при формировании архитектуры вашего кластера. Возможно следует поставить два ингресс контроллера.
Один для всего кластера, без поддержки трейсинга. Второй конкретно для вашего приложения.

## Application

Поскольку были написаны "универсальные" приложения, умеющие отсылать спаны и по jaeger и по otlp протоколу.
В манифестах достаточно определить переменные среды окружения, определяющие параметры нужного нам протокола.

```yaml
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector-agent:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: HTTP
- name: OTEL_EXPORTER_OTLP_INSECURE
  value: "true"
```

Запускаем приложение.

```shell
kubectl -n otel apply -f manifests/applications
```

```shell
kubectl -n otel delete -f manifests/applications
```

## Итого

После запуска приложения сделайте в нём несколько запросов, перейдите по ссылке.

Затем, в интерфейсе opensearch перейдите в дашборд Trace Analytics и посмотрите, как отображается информация о трейсах и
спанах.