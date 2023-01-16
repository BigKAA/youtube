# Для админов и DevOps-ов

Посмотрим на трассировку с другой стороны баррикад.

В качестве платформы будем использовать kubernetes, в котором установим:

1. OpenSearch, для хранения спанов.
2. Jaeger, как платформа для работы с трейсами.
3. Приложения application1 и application2.
4. Ingress controller на базе nginx с включённым механизмом трассировки.

_В моём кластере все PV размещаются на nfs диске._

## Opensearch

В нашем примере opensearch - это просто база данных. Про установку кластера opensearch было отдельное видео.
Поэтому просто даю [ссылку на него](https://github.com/BigKAA/youtube/tree/master/opensearch).

Обратите внимание на `dnsNames` в [сертификате](manifests/opensearch/certs.yaml), который будет выписан для opensearch.
Там должно быть имя сервиса.

```yaml
  dnsNames:
    - localhost
    - esapi.kryukov.local
    - kibana.kryukov.local
    - opensearch-cluster-master.es.svc
    - opensearch-cluster-master.es.cluster.local
```

Создаём namespace.

```shell
kubectl create ns es
```

Добавляем конфигурационные файлы opensearch и сертификаты. В kubernetes обязательно должен быть установлен cert-manager.

```shell
kubectl apply -f manifests/opensearch
```

Теперь установим компоненты opensearch, используя helm chart.

Установка мастер подов:

```shell
helm install master opensearch/opensearch -f charts/opensearch/values-master.yaml -n es
```

Установка data и ingest подов.

```shell
helm install data opensearch/opensearch -f charts/opensearch/values-data.yaml -n es
```

Установка dashboards

```shell
helm install dashboard opensearch/opensearch-dashboards -f charts/opensearch/values-dashboard.yaml -n es
```

В итоге получаем следующие точки доступа к кластеру opensearch:

* https://opensearch-cluster-master.es.svc:9200 - сервис внутри кластера kubernetes, для подключения к API opensearch.
* https://kibana.kryukov.local/ - доступ к dashboard. Пользователь `admin` пароль `password`.

## Jaeger

[Документация](https://www.jaegertracing.io/docs).

Разработчики jaeger заболели популярной ныне болезнью: "А почему бы нам не написать свой оператор для
установки нашего приложения? Пусть он будет как костыль. Его нельзя будет исправить. Шаг влево, шаг вправо - расстрел.
Пусть пользователи почаще вспоминают заклятия на нецензурном языке. Минимум документации, оператор должен быть
загадочным. И вообще - нам всё равно, у нас есть оператор!"

В общем намучался я с этим оператором, который не смог установить jaeger в мой кластер kubernetes.
Поэтому, что бы **не** вспоминать второй русский, пойдём другим путём. Найдём их старый helm chart и попробуем
использовать его. Не получится - выкинем jaeger на свалку и попробуем другой софт. Благо вариантов много.

```shell
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
helm search repo jaeger
```

Создадим namespace в котором будем развёртывать jaeger:

```shell
kubectl create ns jaeger
```

После запуска opensearch нам надо получить сертификат СА, который использовался для подписи его сертификатов.
Так же потребуется создать файл хранилища сертификатов для java приложения. Все необходимые для этого 
приложения и файлы есть непосредственно в контейнере opensearch.

```shell
kubectl -n es exec -it master-0 -c opensearch -- keytool -import -trustcacerts -keystore trust.store -storepass changeit -alias es-root -file config/certs/ca.crt
```

```shell
kubectl -n es exec -it master-0 -c opensearch -- cat config/certs/ca.crt > es.pem
```

```shell
kubectl -n es cp master-0:trust.store trust.store -c opensearch
```

Создадим ConfigMap с этими файлами.

В ConfigMap нельзя хранить бинарные файлы, поэтому мы сначала преобразуем файл хранилища сертификатов в текстовый.

```shell
base64 trust.store > trust.store.b64
```

И создадим ConfigMap, поместив в него оба два файла.

```shell
kubectl -n jaeger create configmap opensearch-tls --from-file=trust.store.b64 --from-file=es.pem
```

Добавим сикрет в котором будет находиться пароль пользователя opensearch.

```shell
kubectl -n jaeger create secret generic opensearch-secret --from-literal=ES_PASSWORD=password
```

Воспользуемся [модифицированным чартом](charts/jaeger/jaeger). В нем пришлось добавить формирование
`trust.store` в `spark` путём добавления init container.

Так же хочу обратить внимание на то, что агент запускается в режиме `hostNetwork`, поэтому у него
обязательно надо изменить `dnsPolicy` на `ClusterFirstWithHostNet`. Иначе агенты не будут видеть
DNS kubernetes.

```yaml
  useHostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
```

Так же в чарте были определены параметры работы с паролями и кое-что по мелочи.

Запускаем jaeger.

```shell
helm install jaeger charts/jaeger/jaeger/ -f charts/jaeger/values.yaml -n jaeger
```

## Ingress controller

Ингресс контроллер ставится при помощи стандартного чарта, с использованием своего values файла.

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

В файле [my-values.yaml](charts/ingress-controller/my-values.yaml) добавим три параметра:

[Список конфигурационных параметров](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#jaeger-propagation-format).

```yaml
  config:
    enable-opentracing: "true"
    jaeger-collector-host: jaeger-agent.jaeger.svc
    jaeger-propagation-format: w3c
```

* Первый включает трассировку **всех** запросов к ингресс контроллеру. Т.е. даже не относящихся к нашему приложению.
* Во втором следует указать **агент** егеря, куда будут передаваться спаны. К сожалению, при конфигурации чарта мы не
  можем "заставить" чарт подставлять в этот параметр IP адрес ноды, на которой запущен ингресс контроллер. Поэтому
  приходится использовать сервис.
* Третий параметр определяет формат trace_id, который будет формировать ingress-controller. По умолчанию
  jaeger, но сейчас рекомендуют переходить на w3c.

Если контроллер запущен, обновим конфигурацию контроллера:

```shell
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -f charts/ingress-controller/my-values.yaml -n ingress-nginx
```

Проверяем.

```shell
kubectl -n ingress-nginx get pods
```

Тут подставьте имя пода, которое выдала предыдущая команда.

```shell
 kubectl -n ingress-nginx exec -it ingress-nginx-controller-58599ff66d-jp7gk -- bash -c "cat /etc/nginx/opentracing.json"
```

## Приложения

С приложением всё просто - два deployment и ingress.

В ингресс необходимо добавить аннотацию, заставляющую контроллер передавать информацию о трейсе
дальше в приложение.

```yaml
  annotations:
    nginx.ingress.kubernetes.io/enable-opentracing: "true"
```

Запустим приложение.

```shell
kubectl apply -f manifests/applications
```

Дальше смотрим трейсы: http://application.kryukov.local