# Добавление трейсинга

## Jaeger

Для сохранения трейсов в тестовой среде будем устанавливать контейнер jaeger в варианте "всё-в-одном".
В этом случае трейсы хранятся во внутренней базе данных в 
[оперативной памяти](https://www.jaegertracing.io/docs/1.41/deployment/#memory). Количество хранимых трейсов не 
ограничено. Но можно поставить ограничение при помощи параметра `--memory.max-traces`.

В файле [docker-compose.yaml](docker-compose.yaml) добавим запуск контейнера jaeger.

```yaml
  jaegertracing:
    image: jaegertracing/all-in-one:1.40.0
    cpu_count: 2
    environment:
      COLLECTOR_OTLP_ENABLED: true
    ports:
      # - "5775:5775/udp" # Agent - deprecated; only used by very old Jaeger clients
      - "6831:6831/udp" # Agent - Thrift protocol used by most current Jaeger clients
      - "6832:6832/udp" # Agent - protocol for Node.js Jaeger client
      - "5778:5778"     # Agent - serve configs, sampling strategies
      - "16686:16686"   # Web UI
      - "14268:14268"   # Collector - HTTP can accept spans directly from clients in jaeger.thrift format over binary thrift protocol
      - "14250:14250"   # Collector - used by jaeger-agent to send spans in model.proto format
      - "4317:4317"     # Collector - OTLP gRPC
      - "4318:4318"     # Collector - OTLP HTTP
```

Разрешим поддержку протокола otlp в коллекторе при помощи переменной среды окружения `COLLECTOR_OTLP_ENABLED: true`.

Набор публикуемых портов включает в себя порты агента, коллектора и jaeger-query.

Доступ к WEB интерфейсу jaeger [http://127.0.0.1:16686](http://127.0.0.1:16686).

## Nginx

Поскольку перед нашим приложением установлен nginx, хотелось бы включать в трейсы запросы начиная с самого входа.
Т.е. учитывать задержки, возникающие на прокси.

На данный момент трейсинг в Nginx реализуется при помощи модуля
[opentelemetry-cpp-contrib](https://github.com/open-telemetry/opentelemetry-cpp-contrib).
Документация по проекту отвратительная. Но попробуем его включить.

Поддерживается только OTLP HTTP, т.е. придется подключаться непосредственно к коллектору.

В базовый контейнер nginx модуль трассировки не включён, поэтому придётся создавать свой контейнер. Для этого
будем использовать соответствующий [Dockerfile](nginx/Dockerfile).

Метод, используемый в Dockerfile работает только с nginx версий 1.22.0, 1.23.0, 1.23.1. И только с
архитектурой процессоров Intel. На M1 даже не пытайтесь :). Подробности смотрите 
[тут](https://github.com/open-telemetry/opentelemetry-cpp-contrib/tree/main/instrumentation/otel-webserver-module#nginx-webserver-module).

Если кратко, то при сборке контейнера используется архив с заранее скомпилированными модулями для определённых
версий nginx для архитектуры процессоров Intel. Если возникнет необходимость для сборки контейнера для других
версий и архитектур, придётся писать полноценную процедуру сборку nginx.

Запуск nginx реализован следующим образом:

```yaml
  nginx:
    image: application_otlp_nginx:1.23.1
    build:
      context: nginx
    ports:
      - "8080:80"
    volumes:
      - ${PWD}/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ${PWD}/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf
      - ${PWD}/nginx/opentelemetry_module.conf:/etc/nginx/conf.d/opentelemetry_module.conf
```

Включение модуля opentelemetry добавлено в конфигурационный файл [nginx.conf](nginx/nginx.conf)

```nginx configuration
load_module /opt/opentelemetry-webserver-sdk/WebServerModule/Nginx/1.23.1/ngx_http_opentelemetry_module.so;
```

Обратите внимание на путь к модулю. Там устанавливается несколько вариантов под разные версии nginx.

Так же необходимо подготовить конфигурационный файл [opentelemetry_module.conf](nginx/opentelemetry_module.conf).

```
NginxModuleEnabled ON;
NginxModuleOtelSpanExporter otlp;
NginxModuleOtelExporterEndpoint jaegertracing:4317;
NginxModuleServiceName nginx;
NginxModuleServiceNamespace NginxNamespace;
NginxModuleServiceInstanceId Nginx;
NginxModuleResolveBackends ON;
NginxModuleTraceAsError ON;
```

* Включаем трейсы: `NginxModuleEnabled ON`
* Явно указываем какой экспортер будет использоваться: `NginxModuleOtelSpanExporter otlp`
* Определяем адрес и порт, куда будут отсылаться span: `NginxModuleOtelExporterEndpoint jaegertracing:4317`.
  Смотрите определение портов контейнера jaeger.
* Определяем имя сервиса, которое будет показываться в span, отсылаемых nginx: `NginxModuleServiceName nginx`

В общем проект забавный. Но радует то, что в nginx ingress controller все включено по умолчанию.

## application1

Внесём некоторые дополнения в ранее написанное приложение.

Сначала определим базовые параметры:

```python
resource = Resource(attributes={
    SERVICE_NAME: "application1"
})
```

Установим имя сервиса: `SERVICE_NAME: "application1"`. В дальнейшем все span будут содержать это имя. Имя сервиса можно
не определять в коде, а воспользоваться переменной среды окружения `OTEL_SERVICE_NAME=application1`.

Попытаемся написать "универсальное" приложение, которое умеет отсылать спаны используя разные протоколы.
Определить протокол, а следовательно используемый экспортёр, можно при помощи переменных среды окружения.

_Это не идеальный вариант. И в дальнейшем мы столкнемся с проблемой конфигурации приложения. По-хорошему, необходимо 
добавить возможность конфигурации при помощи конфигурационного файла и аргументов командной строки._

```python
def select_processor() -> SpanExporter:
    if "OTEL_EXPORTER_OTLP_ENDPOINT" in os.environ:
        return OTLPSpanExporter()
    elif "OTEL_EXPORTER_JAEGER_AGENT_HOST" in os.environ
            and "OTEL_EXPORTER_JAEGER_AGENT_PORT" in os.environ:
        return JaegerExporter()
    print("Not set exporter in env variable OTEL_EXPORTER_OTLP_ENDPOINT or"
          + " OTEL_EXPORTER_JAEGER_AGENT_HOST| OTEL_EXPORTER_JAEGER_AGENT_PORT]", file=sys.stderr)
    exit(1)


provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(select_processor())
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)
```

Поскольку планируется использовать Jaeger-agent, файле `docker-compose.yaml` определим следующие переменные среды 
окружения при запуске контейнера:

```
OTEL_EXPORTER_JAEGER_AGENT_HOST: "jaegertracing"
OTEL_EXPORTER_JAEGER_AGENT_PORT: 6831
```

В итоге мы получаем объект `tracer`, который будем использовать для формирования span.

### root()

Добавим трассировку в функцию root().

```python
@app.route("/")
@app.route("/index.html")
def root():
    with tracer.start_as_current_span(
            "/",
            context=extract(request.headers),
            kind=trace.SpanKind.SERVER,
            attributes=collect_request_attributes(request.environ)
    ) as span:
        span.set_attribute("function", "root")
        span.set_attribute(SpanAttributes.HTTP_METHOD, "GET")

        span.add_event("The root method")
        # Посмотрим заголовки
        span.add_event(f"Headers \n {request.headers}")
        return render_template("index.html")
```

`tracer.start_as_current_span` - Создаёт span. Обязательным параметром при определении span является только его имя. ё
В нашем случае это будет путь в запросе.

`kind` - заранее определенные константы. Как я заметил, на практике их используют крайне редко. Но мы на всякий
случай обозначим наш спан, как созданный на сервере, а не на клиенте.

`attributes` можно определить сразу, можно добавить позднее при помощи функции `set_attribute`.

Очень важный фрагмент кода:

```python
context = extract(request.headers)
```

Он отвечает за "связывание" нескольких span в один трейс.

Как я писал раньше, трейс объединяет между собой несколько спанов. Каждый трейс имеет уникальный id.
Что-то типа: `00-23af8b3bbcab3eec236f11d649d3a516-f5c4561d7e9d3764-01`.
При формировании span можно явным образом указать к какому trace_id он относится. Если необходимо связать несколько
span из различных приложений в один трейс, в нашем случае nginx и application1. Мы должны каким то образом передать
trace_id из nginx в aplication1. В случае HTTP запросов, id помещают в заголовок (header) запроса. Модуль nginx 
при передаче запроса в application1 так и поступает. Нам остаётся получить из заголовков запроса этот id и поместить 
его в контекст span. За получения id из запроса отвечает функция `extract`.

_Если при создании спан не указывать trace_id, создаётся новый трейс. Т.е. генерируется новый
trace_id и добавляется в существующий спан._

Таким образом, наш span будет соотнесён с трейсом, который начался при обращении пользователя к nginx.

`add_event("The root method")` - добавляем в span событие. В терминах jaeger - лог.

`span.add_event(f"Headers \n {request.headers}")` - добавляем в лог span ещё одно событие. _Тут мог быть, например
запрос к БД_. Ну а так, просто смотрим какие заголовки мы получили от предыдущего приложения.

В данном примере `tracer.start_as_current_span` вызывался внутри оператора `with`, поэтому он будет закрыт автоматически
после завершения работы функции `root()`.

### base()

Дополнения в функции base().

```python
# Добавим информацию о нашем трейсе в запрос ко второму сервису
headers = {}
TraceContextTextMapPropagator().inject(headers)

# Пошлем запрос во второе приложение
resp = requests.get(f"{os.getenv('APP2')}/api/v1/data", headers=headers)
```

В этой функции span формируется аналогично функции `root()`. Но внутри мы посылаем HTTP запрос к application2 и неплохо
бы добавить в заголовок этого запроса trace_id текущего спан, что бы связать в одном трейсе все три приложения: 
nginx, application1 и application2.

Делается это при помощи функции `TraceContextTextMapPropagator().inject(headers)`. В дальнейшем эти заголовки
передаются при вызове `requests.get`. В application2 мы их получим и добавим span приложения к этому трейсу.

## application2

В этом приложении у нас только одна функция эмулирующая запрос к базе данных. В ней есть две рандомных задержки. И два
span.

На примере второго span показано как можно создать дочерний span. Он формируется такой же функцией, как и родительский.

```python
@app.route("/api/v1/data")
def db_request_emulation():
    with tracer.start_as_current_span(
            "/api/v1/data",
            context=extract(request.headers),
            kind=trace.SpanKind.SERVER,
            attributes=collect_request_attributes(request.environ)
    ) as span:
        span.set_attribute("function", "db_request_emulation")
        span.set_attribute(SpanAttributes.HTTP_METHOD, "GET")

        # Посмотрим заголовки
        span.add_event(f"Headers \n {request.headers}")

        # generate 1-st delay and value
        delay: float = random.uniform(0.1, 0.9)
        span.add_event(f"1-s request, delay - {delay}")
        time.sleep(delay)
        data[0]['value'] = delay
        with tracer.start_as_current_span("/api/v1/data sub_request") as rspan:
            # generate 2-nd delay and value
            delay: float = random.uniform(0.1, 0.9)
            rspan.add_event(f"2-d request, delay - {delay}")
            time.sleep(delay)
            data[1]['value'] = delay
            return jsonify({'data': data})
```

## Итого

Запустите приложение при помощи docker-compose.

Сделайте пару запросов к приложению на http://120.0.0.1:8080/. Нажмите на внутреннюю
ссылку.

Затем посмотрите на трейсы, который стали доступны в WEB интерфейсе jaeger - http://127.0.0.1:16686.