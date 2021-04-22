# Метрики etcd

Особенности:
* сертификаты клиента.
  * /etc/kubernetes/ssl/apiserver-etcd-client.crt
  * /etc/kubernetes/ssl/apiserver-etcd-client.key
  * Необходимо обновлять.
* В данном примере etcd виден внутри кластера.

Проверить наличие метрик:

    curl --cert /etc/kubernetes/ssl/apiserver-etcd-client.crt \
      --key /etc/kubernetes/ssl/apiserver-etcd-client.key  \
      --cacert /etc/kubernetes/ssl/ca.crt --insecure \
      https://192.168.218.171:2379/metrics \

Создаём secret

    kubectl -n monitoring create secret generic etcd-client \
      --from-file=/etc/kubernetes/ssl/apiserver-etcd-client.key \
      --from-file /etc/kubernetes/ssl/apiserver-etcd-client.crt

Подключаем его как volume к контейнеру prometheus

