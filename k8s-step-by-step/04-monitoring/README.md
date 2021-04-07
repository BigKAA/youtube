# Мониторинг 

## SSL сертификат

Сертификат для ingress был создан в предыдущем видео. См. 03-utils/02-certs.yaml

Если вы его не создавали, сначала добавьте сикрет:

    kubectl -n monitoring create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt --key=/etc/kubernetes/ssl/ca.key

Затем примените файл 00-certs.yaml

## Схема

![](images/scheme.jpg)

### Хранилище метрик - victoriametrics

[victoriamerics](01-victoriamerics/README.md)

### Сбор метрик - prometheus

[promatheus](02-promatheus/README.md)

### Отображение метрик - grafana

[grafana](03-grafana/README.md)
