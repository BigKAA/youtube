# Openresty-art Helm Chart

openresty-art - тестовый helm chart, пример для демонстрации, используемый в серии
видео [Основы helm chart](https://www.youtube.com/playlist?list=PLmxqUDFl0XM7e0d0ixZ82zlcBprpMfEpk).

## Конфигурационные параметры

| Параметр                         | Значение по умолчанию | Описание                                                                                   |
|:---------------------------------|:---------------------:|:-------------------------------------------------------------------------------------------|
| nameOverride                     |          ""           | Строка для частичного переопределения шаблона openresty-art.fullname (сохранит имя релиза) |
| fullnameOverride                 |          ""           | Строка для частичного переопределения шаблона openresty-art.fullname                       |
| application.reloader             |         false         | Включение аннотации stakater reloader                                                      |
| application.replicaCount         |           1           | Количество реплик                                                                          |
| application.revisionHistoryLimit |           3           | Ограничение revisionHistoryLimit                                                           |
| application.podAnnotations       |          {}           | Аннотации, добавляемые в под                                                               |
| application.imagePullSecrets     |          []           | Secret для доступа к containers repositiry                                                 |
| application.image.repository     |  openresty/openresty  | Путь к образу контейнера в репозитории                                                     |
| application.image.tag            |          ""           | Container tag                                                                              |
| application.image.pullPolicy     |     IfNotPresent      | Политика                                                                                   |
| application.probes               |                       | Настрйоки проб                                                                             |
| application.resources            |          {}           | Определение ресурсов.                                                                      |
| service.type                     |       ClusterIP       | Тип сервиса. Возможные варианты: ClusterIp или NodePort                                    |
| service.port                     |          80           | Порт сервиса                                                                               |
| service.name                     |          ""           | Имя сервиса                                                                                |
| service.nodePort                 |          ""           | Номер порта. Имеет смысл только если service.type = NodePort                               |
| ingress.enabled                         |         false         | Включение ingress                                                                          |

## Использование чарта







