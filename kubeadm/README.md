# Управление кластером при помощи kubeadm

## Немного необязательной информации

* [Почему не kubespray](why_not_kubespray.md).
* [Описание тестового стенда](test_stand.md).
* [Предварительные действия на всех машинах кластера](preliminary_actions.md).

## HA или не HA?

Если вы планируете использовать только одну control node в кластере, этот раздел можно пропустить.

Если у вас в кластере будет несколько control nodes, рекомендую всегда включать High availability для доступа к
kubernetes API из-за пределов кластера.

* [Как включить High availability](ha_cluster.md).

## Установка кластера

* [Первая control нода](first_control_node.md).
* [Добавление дополнительных control нод](another-control-nodes.md).
* [Добавление worker ноды](worker-nodes.md).
* [Проверка работоспособности](check.md).

## Обслуживание кластера

* [Обновление версии кластера](update.md).
* [Удаление нод](delete_node.md).
* [Обновление сертификатов](certificates.md).
