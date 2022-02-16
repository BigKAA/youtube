# Сбор метрик.

Для того, что бы начать правильно обрабатывать метрики, сначала следует понять какие метрики нам доступны.
Т.е. получить список приложений и их метрик.

## Jobs, определённые в values по умолчанию.

Сначала посмотрим стандартные настройки vmaget, которые есть в values по умолчанию.

### job kubernetes-apiservers

Получить список текущих метрик API сервера можно следующим образом.

Находим secret vmagent. Нам необходимо знать его имя.

    kubectl -n monitoring get secrets

В переменную TOKEN помещаем токен ServiceAccount, с правами которого работает vmagent.

    TOKEN=$(kubectl -n monitoring get secrets vmagent-sys-token-lgs5k -o jsonpath="{.data.token}" | base64 --decode)

Используя полученный токен, посылаем запрос к API серверу

    curl -H "Authorization: Bearer $TOKEN" -k https://192.168.218.171:6443/metrics | less

Так же можно посмотреть [исходные коды приложения](https://github.com/kubernetes/apiserver/blob/release-1.23/pkg/endpoints/metrics/metrics.go)
для понимания, какие метрики оно генерирует.

Метрики начинаются с `apiserver_*`, `etcd_*`.

### job kubernetes-nodes

Пример получения метрик конкретной ноды кластера.

    curl -H "Authorization: Bearer $TOKEN" \
    -k https://192.168.218.171:6443/api/v1/nodes/control1.kryukov.local/proxy/metrics | less

Основные метрики начинаются с `kubelet_*`. Например: `kubelet_running_pods`
позволяет узнать общее количество запущенных подов.

### job kubernetes-nodes-cadvisor

     curl -H "Authorization: Bearer $TOKEN" \
     -k https://192.168.218.171:6443/api/v1/nodes/control1.kryukov.local/proxy/metrics/cadvisor | less

Основные метрики начинаются с `container_*`. 

Так же можно посмотреть базовые метрики по серверу: `machine_*`. Но эту информацию лучше
брать из метрик node-exporter

Документацию по метрикам можно посмотреть [тут](https://github.com/google/cadvisor/blob/master/docs/storage/prometheus.md).

### Сбор метрик через аннотации

Остальные jobs в values по умолчанию используют механизм аннотаций. Они отличаются друг от
друга местом расположения этих аннотаций.

* job_name: "kubernetes-service-endpoints"
* job_name: "kubernetes-service-endpoints-slow"
* job_name: "kubernetes-services"
* job_name: "kubernetes-pods"

Параметры, которые можно использовать в аннотациях:

* `prometheus.io/scrape`: Включает сбор метрик `true`
* `prometheus.io/scheme`: `https` или `http`.
* `prometheus.io/path`: Значение по умолчанию: `/metrics`. Имеет смысл определять параметр
только в случае другого пути.
* `prometheus.io/port`: Порт, на ктором слушает запросы приложение (сервис).

Если подключиться к WEB интерфейсу vmagent. То в списке targets мы увидим что вышеперечисленные jobs уже
собирают метрики.

    https://vmagent.kryukov.local/targets

kubernetes-pods:
* app="cert-manager"
* app="metallb"
* k8s_app="nodelocaldns"

kubernetes-service-endpoints:
* app_kubernetes_io_name="ingress-nginx"
* k8s_app="kube-dns" (coredns)

## Jobs, добавленные в my-values.

Дополнительно к стандартным job мы добавили два таргета для получения метрик из node-exporter
и kube-state-metrics

### node-exporter

Получим ip подов node-exporter в нашем кластере. Для этого можно посмотреть 
соответствующий endpoint:

    kubectl -n monitoring get ep nexporter-prometheus-node-exporter

Посмотрим метрики одного из экспортеров:

    curl http://192.168.218.171:9100/metrics | less

Вопрос на засыпку. Почему мы не обращались к сервису? 
    
    kubectl -n monitoring get svc nexporter-prometheus-node-exporter
    curl http://SERVICE_IP:9100/metrics | less

Необходимые нам метрики начинаются с `node_*`.

### kube-state-metrics

Тут всё просто. Явно указан сервис к которому следует обращаться за метриками:

Получаем IP адрес сервиса:

    kubectl -n monitoring get svc ksm-kube-state-metrics

Смотрим какие метрики нам доступны:

    curl http://10.233.59.116:8080/metrics | less

Метрики начинаются с `kube_*`

## Итого

В дальнейшем мы сможем добавлять сбор новых метрик:

* Если приложение находится в kubernetes - правильное описание аннотаций. В этом случае метрики будут собираться
автоматически. Т.е. конфигурация vmagent происходит только один раз.
* Если приложения находятся за пределами кластера kuberntes - запускаем отдельный экземпляр vmaget. При этом не забываем
отключить сбор метрик по умолчанию в values.

## Видео

[<img src="https://img.youtube.com/vi/t2kjG_JBmpk/maxresdefault.jpg" width="50%">](https://youtu.be/t2kjG_JBmpk)
