# Longhorn

[Документация](https://longhorn.io/).

## Подготовка

Все дальнейшие действия рассчитаны на установку в мой кластер:

    # kubectl get nodes
    NAME                     STATUS   ROLES           AGE   VERSION
    control1.kryukov.local   Ready    control-plane   36m   v1.24.6
    control2.kryukov.local   Ready    control-plane   35m   v1.24.6
    control3.kryukov.local   Ready    control-plane   36m   v1.24.6
    db1.kryukov.local        Ready    <none>          35m   v1.24.6
    worker1.kryukov.local    Ready    <none>          35m   v1.24.6
    worker2.kryukov.local    Ready    <none>          35m   v1.24.6
    worker3.kryukov.local    Ready    <none>          35m   v1.24.6

К трём нодам (worker{1-3}) добавлены диски, смонтированные в /mnt/data. Эти
диски будет использовать Longhorn.

Скрипт [prepare.sh](prepare.sh) устанавливает базовые компоненты кластера на основании примера из [1.25](../1.25/).

```shell
./prepare.sh
```

Playbook [prepare_host.yaml](prepare_host.yaml) устанавливает необходимые для работы Longhorn компоненты.

```shell
ansible-playbook -i 00-ansible/hosts.yaml 00-ansible/prepare_host.yaml
```

## Установка

```shell
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn -n longhorn-system --create-namespace
```

Первый запуск будет долгим.

Добавим ingress с аутентификацией.

```shell
USER=admin; PASSWORD=password; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" 
```

Добавляем полученную строку в сикрет.

```shell
kubectl -n longhorn-system apply -f manifests/00-basic-auth-secret.yaml
kubectl -n longhorn-system apply -f manifests/01-ingress-ui.yaml
kubectl -n longhorn-system apply -f manifests/02-storage-class.yaml
```

## Используем

```shell
kubectl create ns postgresql
kubectl -n postgresql apply -f postgresql
```

## Улучшаем

Удалим базу данных, pvc, storage classes

```shell
kubectl -n postgresql delete -f postgresql
helm uninstall longhorn -n longhorn-system 
kubectl delete StorageClass data-db
kubectl delete StorageClass data
```

### Подготовка нод кластера

Пометим ноды кластера, диски которых будет использовать Longhorn.

Скрипт [prepare_longhorn.sh](prepare_longhorn.sh) устанавливает аннотации на ноды на которых
находятся диски, которые будет использовать Longhorn.

    node.longhorn.io/default-node-tags: '["ssd","storage"]'
 
    node.longhorn.io/default-disks-config: 
    '[
        {   
            "name":"ssd-disk", 
            "path":"/mnt/data",
            "allowScheduling":false,
            "storageReserved":10485760,
            "tags": ["ssd","fast"]
        }
    ]'

kubectl annotate node worker1.kryukov.local node.longhorn.io/default-node-tags='["ssd","storage"]'


helm repo add longhorn https://charts.longhorn.io

--set defaultSetting.createDefaultDiskLabeledNodes=true