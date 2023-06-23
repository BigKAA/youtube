# Semaphore

Заготовки. Не продакшен

* https://docs.ansible-semaphore.com/
* https://github.com/ansible-semaphore/semaphore


```shell
kubectl create ns semaphore
```

```shell
kubectl -n semaphore apply -f manifests
```

```shell
kubectl -n semaphore delete -f manifests
```

```shell
kubectl -n semaphore apply -f postgres
```

```shell
kubectl -n semaphore delete -f postgres
```