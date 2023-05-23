# Uniproxy

Тестовое приложение, используемое для демонстрации сетевых политик в кластере kubernetes.

## Конфигурация

Конфигурация приложения происходит при помощи переменных среды окружения.

* **CONFIG_FILE** - Путь к конфигурационному файлу и его имя. Значение по умолчанию: `/etc/uniproxy/uniproxy.yaml`.
* **LOG_LEVEL** - Значение по умолчанию: `info`.
* **BIND_ADDR** - Значение по умолчанию: `0.0.0.0:8080`. _В случае использования готового контейнера,
  значение данной переменной менять не рекомендуется, поскольку оно уже определено в Dockerfile._

### Конфигурационный файл

В конфигурационном файле определяется массив контекстов.

В каждом контексте задаётся три параметра:

* **path** - контекст.
* **proxyPath** - URL, куда будет переслан запрос. Если не определён - запрос дальше не пересылается.
Полученный ответ будет подставлен в качестве значения в поле `returnMessage`.
* **comment** - Любая текстовая строка. Можно использовать в качестве комментария.

```yaml
paths:
  - path: "/"
    proxyPath: "http://some.namespace.srv:8080/"
    comment: "Root"
  - path: "/path"
    proxyPath: "https://reqbin.com/echo/get/json"
    comment: "Sample path"
  - path: "/stub"
    proxyPath: ""
    comment: "Stub path"
```

## Возвращаемое значение

Приложение возвращает значение в формате `application/json`.

Пример ответа приложения:

```shell
curl -s http://127.0.0.1:8080/ | jq
```

```json
{
  "path": "/",
  "proxyPath": "http://some.namespace.srv:8080/",
  "returnHeader": "Root",
  "returnMessage": {
    "Op": "Get",
    "URL": "http://some.namespace.srv:8080/",
    "Err": {
      "Op": "dial",
      "Net": "tcp",
      "Source": null,
      "Addr": null,
      "Err": {
        "Err": "no such host",
        "Name": "some.namespace.srv",
        "Server": "",
        "IsTimeout": false,
        "IsTemporary": false,
        "IsNotFound": true
      }
    }
  }
}
```

```shell
curl -s http://127.0.0.1:8080/stub | jq
```

```json
{
  "path": "/stub",
  "proxyPath": "",
  "returnHeader": "Stub path"
}
```

## Build image

На маке:

```shell
docker build -t bigkaa/uniproxy:0.1.0-arm64 .
docker push bigkaa/uniproxy:0.1.0-arm64
```

На linux:

```shell
docker build -t bigkaa/uniproxy:0.1.0-amd64 .
docker push bigkaa/uniproxy:0.1.0-amd64
```

Собираем в один образ:

```shell
docker manifest create bigkaa/uniproxy:0.1.0 \
--amend bigkaa/uniproxy:0.1.0-arm64 \
--amend bigkaa/uniproxy:0.1.0-amd64

docker manifest push docker.io/bigkaa/uniproxy:0.1.0
```