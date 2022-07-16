# Opensearch helm chart 

Добавить на нодах, где будет устанавливаться opensearch

    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    sysctl -w vm.max_map_count=262144 

После установки можно зайти в под и проверить, что мы получаем ответ от кластера.

    curl -XGET https://localhost:9200 -u 'admin:admin' --insecure