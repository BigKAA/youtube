# Пользователи и мониторинг

## Тестовое приложение

Сначала средствами rancher создадим проект `Test-app`.

Добавим пользователя в Rancher. При добавлении пользователя выберем глобальную роль `User-Base`.
Этот пользователь предназначен для управления проектом `Test-app`.

В проекте `Test-app` в меню выберите `Edit Config`. В закладке `Members` добавьте пользователя с
ролью `Member`, нажмите кнопку `Save`.

В проекте `Monitoring` в меню выберите `Edit Config`. В закладке `Members` добавьте пользователя с
custom ролями: `Monitoring View` и `Manage Services`.

Нажмите кнопку `Save`.

Выйдите из системы и зайдите новым пользователем. Выберите кластер, в котором вы 
будете работать.

Слева выберите раздел мониторинг.

В проекте `Test-app` создайте namespace `test-app`.

Запустим тестовое приложение.

```shell
kubectl -n test-app apply -f manifests/application.yaml
```

## Сбор метрик

Добавим target в текущий экземпляр Prometheus при помощи `ServiceMonitor`.

```shell
kubectl -n test-app apply -f manifests/service-monitor.yaml
```

Через некоторое время в списке targets Prometheus появится наше приложение.

## Grafana dashboard

Для того, что бы добавить кастомный дашборд в grafana необходимо каким либо образом получить его json файл.
Например, его можно сделать непосредственно в grafana. Логопас по умолчанию: `admin/prom-operator` 

Затем json помещают в ConfigMap. Пример можно посмотреть в файле 
[dashboard.yaml](../02-monitoring/manifests/dashboard.yaml).

Важно понимать, что в ConfigMap обязательно необходимо добавить "волшебную" метку:

```yaml
metadata:
  labels:
    grafana_dashboard: "1"
```

## Видео

* Youtube: https://youtu.be/GBEhtuTj5M0
* VK: https://vk.com/video7111833_456239230
* Telegramm: https://t.me/arturkryukov/173
* Rutube: https://rutube.ru/video/bc9187aa7ac8d4c14527ce55ace7375a/

Плейлист цикла по rancher: 

* Youtube: https://www.youtube.com/playlist?list=PLmxqUDFl0XM5x96wHJbBGeqNB1vhKfVv9
* VK: https://vk.com/video/playlist/7111833_5
* Rutube: https://rutube.ru/plst/265514/