# Удаление нод.

## Удаление worker ноды

Сначала удаляем ноду из кластера.

```shell
kubectl delete node worker1.kryukov.local
```

Затем на самой ноде удалем приложения кластера.

```shell
kubeadm reset
```

После `kubeadm reset` containerd (или то что вы используете) не выключается.
Есть вероятность, что какие-то контейнеры продолжат работать.

Тут либо выключаем containerd, либо вручную останавливаем все запущенные контейнеры.

## Удаление control ноды

В случае control ноды, делаем всё так же как и в случае worker ноды. Но есть
нюансы.

Если нода отключилась аварийно, удаление ноды из кластера при помощи 
kubectl будет недостаточно. Необходимо посмотреть состояние кластера etcd.
Если на упавшей ноде был один из серверов etcd, то его надо вручную
удалить из кластера.

_Дальнейшие действия показаны для установленного при помощи kubeadm etcd
кластера._

Переходим на рабочую control ноду. Смотрим на каком IP и порту слушает запросы 
etcd сервер

```shell
ss -nltp | grep 2379
```

Получаем название подов etcd сервера

```shell
kubectl -n kube-system get pods | grep etcd
```

Получаем список членов кластера etcd. Нам нужен id неработающего сервера.

```shell
kubectl -n kube-system exec etcd-control1.kryukov.local -- etcdctl \
  --endpoints '192.168.218.171:2379' \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  member list
```

Удаляем неработающий сервер из списка.

```shell
kubectl -n kube-system exec etcd-control1.kryukov.local -- etcdctl \
  --endpoints '192.168.218.171:2379' \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  member remove b7460bb084b5c02b
```


