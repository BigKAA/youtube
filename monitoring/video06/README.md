# Video 6. Необходимые дашборды.

## Дашборды по...

* uid: art-deployment - данные по deployments.
* 



## Общий дашборд кластера.

За основу возьмём дашборд https://grafana.com/grafana/dashboards/6417

В grafana создадим отдельный раздел для шаблонов, находящихся в разработке. И в него импортируем дашборд.

После импорта понимаем, что шаблон практически не рабочий. Придётся его допиливать.

### Переменные

#### ds - выбор datasource

* General
  * Name - ds
  * Type - Data source
* Data source options
  * Type - Prometheus

#### node - выбор node кластера

* General
    * Name - node
    * Type - Query
* Query Options
    * Data source - `${ds}`
    * Query - `kube_node_info`
    * Regex - `/node="(?<text>[^"]+)/`
    * Sort - Alphabetical (asc)
* Selection options
  * Multi-value - on
  * Include All option - on

#### namespace

* General
    * Name - namespace
    * Type - Query
* Query Options
    * Data source - `${ds}`
    * Query - `kube_namespace_created`
    * Regex - `/namespace="(?<text>[^"]+)/g`
    * Sort - Alphabetical (asc)
* Selection options
    * Multi-value - off
    * Include All option - on

#### instance

* General
    * Name - instance
    * Type - Query
* Query Options
    * Data source - `${ds}`
    * Query - `kube_node_info{node=~"$node"}`
    * Regex - `/internal_ip="(?<text>[^"]+)/`
    * Sort - Alphabetical (asc)

### Замена datasource

Открываем JSON модель и ищем по ключевому слову `datasource`. Будет найдено что то типа:

```yaml
"uid": "PC7A11E9A55DE2B14"
```

Заменяем число на `${ds}`

### Рутина :(

Дальше в основном будет проблема изменённого названия метрик. Тут придётся каждую панель править вручную.

Например, открываем первую панель "Cluster Pod Usage". В другом окне браузера открываем Explore.

Сразу видно, что в шаблоне по умолчанию: `kube_node_status_allocatable_pods`. А в текущих реалиях
метрику надо брать уже такую: `kube_node_status_allocatable{resource="pods"}`

Так же по умолчанию указаны все ноды: `kube_node_status_allocatable_pods{node=~".*"}`

В итоге заменяем правило и получаем: 

    sum(kube_pod_info{node=~"$node"}) / sum(kube_node_status_allocatable{node=~"${node}", resource="pods"})

Так же следует изменить Standard options -> Max со 100 на 1.

И панель заработает.

### Финальный вариант

А потом helm chart grafana начал не по-детски глючить. Он отказался генерировать configMaps с дашбордами.

Поэтому переходим на работу с манифестами.

    helm template grafana charts/grafana/ -f charts/grafana/my-values.yaml \
    -n monitoring > manifests/grafana.yaml

Немного чистим манифесты. Выносим дашборды в отдельный configMaps. И в итоге получаем вполне работоспособную
grafana.


