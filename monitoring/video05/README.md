# Video 05 - Grafana

Добавим пару конфигурационных параметров, что бы графана генерировала правильные url при созданнии invite
для пользователей.

В my-values добавляем объект:

```yaml
  grafana.ini:
    server:
      domain: grafana.kryukov.local
      root_url: https://grafana.kryukov.local
```

## Автоматическое добавление dashboards

После установки grafana мы можем добавлять в неё новые дашборды. Но если система будет разворачиваться "с нуля",
мы каждый раз будем получать пустую grafana. И каждый раз будем руками добавлять новые dashboards.

Посмотрим, как это вопрос можно автоматизировать. 

Самый простой (по трудозатратам) dashboard на котором мы можем поэкспериментировать - это 
[dashboard node-exporter](https://grafana.com/grafana/dashboards/1860).

### Загрузка дашборда с сайта grafana.com

В файле my-values добавляем провайдера:

```yaml
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: true
        editable: false
        options:
          path: /var/lib/grafana/dashboards/default
```

Там же добавляем dashboard node-exporter по его Id на сайте https://grafana.com/grafana/dashboards

```yaml
  dashboards:
    default:
      node-exporter:
        gnetId: 1860
        revision: 25
        datasource: Victoria
```

### Загрузка дашборда из github

Создадим в директории dashboards файл node-exporter.json. Поместим в него исходник и изменим в
нём поле uid на `"uid": "art-node-exporter"`. Явно указав uid dashboard.

Заодно сразу укажем источник данных:

```json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "Victoria",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  }
}
```

Теперь файл шаблона будет доступен в git. Соответственно надо поменять
параметры загрузки шаблона в my-values:

```yaml
 dashboards:
    default:
      node-exporter:
        url: 'https://raw.githubusercontent.com/BigKAA/youtube/monitoring/monitoring/video05/dashboards/node-exporter.json'
```

### Загрузка дашборда непосредственно из чарта.

Самый удобный вариант поместить файл дашборда прямо внутри чарта. Поскольку мы используем чарт обёртку, нам
придётся сделать несколько дополнительных дйествий.

Создадим внутри текущего чарта директорию charts. Перейдём в неё.

    helm pull grafana/grafana --untar

В появившемся subchart, в директорию dashboards добавляем json файл с dashboard.

В my-values меняем источник на:

```yaml
  dashboards:
    default:
      node-exporter:
        file: dashboards/node-exporter.json'
```

Но что-то пошло не так :) Подробности смотрите в видео.

## Видео

[<img src="https://img.youtube.com/vi/kJpfUTRP2L8/maxresdefault.jpg" width="50%">](https://youtu.be/kJpfUTRP2L8)