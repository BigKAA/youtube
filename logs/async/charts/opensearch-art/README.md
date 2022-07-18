# Opensearch envelope helm chart 

Чарт обёртка, включает в себя чарты opensearch и opensearch dashboards.

**Важно!** Добавить на нодах, где будет устанавливаться opensearch

    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    sysctl -w vm.max_map_count=262144 

После установки можно проверить, что мы получаем ответ от кластера.

    curl -XGET https://SERVICE_IP:9200 -u 'admin:admin' --insecure