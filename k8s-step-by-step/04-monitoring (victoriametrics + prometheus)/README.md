# Мониторинг 

## SSL сертификат

Сертификат для ingress был создан в предыдущем видео. См. 03-utils/02-certs.yaml

Если вы его не создавали, сначала добавьте сикрет:

    kubectl -n monitoring create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt --key=/etc/kubernetes/ssl/ca.key

Затем примените файл 00-certs.yaml

## Схема

![схема](images/scheme.jpg)

### Хранилище метрик - victoriametrics

[victoriamerics](01-victoriametrics/README.md)

### Сбор метрик - prometheus

[prometheus](02-prometheus/README.md)

### Отображение метрик - grafana

[grafana](03-grafana/README.md)

### Видео

[<img src="https://img.youtube.com/vi/nEzXmDYDqg8/maxresdefault.jpg" width="50%">](https://youtu.be/nEzXmDYDqg8)

[<img src="https://img.youtube.com/vi/trHNN-X_BUE/maxresdefault.jpg" width="50%">](https://youtu.be/trHNN-X_BUE)