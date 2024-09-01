# images volumes

В kubernetes v1.31 появился новый тип volume - [image](https://kubernetes.io/docs/concepts/storage/volumes/#image).

> Тома типа image представляют собой объект [OCI](https://github.com/opencontainers/distribution-spec/) (образ контейнера или артефакт), который доступен на хост-компьютере kubelet.

## Создание артефакта в OCI хранилище

Некоторые приложения, например [helm](https://helm.sh/blog/storing-charts-in-oci/#helm) или [ormb](https://github.com/kleveross/ormb), могут самостоятельно создавать артефакты в OCI хранилище. Но если вам потребуется разместить в нём произвольный набор файлов, рекомендую воспользоваться приложением ORAS.

### ORAS

Для создания (и не только) артефактов в OCI хранилище можно использовать приложение [oras](https://oras.land/). 

Установка приложения описана в [документации](https://oras.land/docs/install/).

Если вы привыкли к контейнерам, то для вас разработчики создали контейнер с приложением:

```shell
docker run -it --rm -v $(pwd):/workspace ghcr.io/oras-project/oras:v1.2.0 help
```

### Создание артефакта

В качестве примера будем использовать файлы из директории `files`.

Сначала подключимся к репозиторию:

```shell
docker run -it --rm -v $(pwd):/workspace ghcr.io/oras-project/oras:v1.2.0 \
       login -u admin registry.kryukov.local
```

Грузим артефакт в хранилище:

```shell
docker run -it --rm -v $(pwd):/workspace ghcr.io/oras-project/oras:v1.2.0 \
       push -u admin registry.kryukov.local/library/files:1.0.0 ./html/:text/html
```

Проверяем:

```shell
docker run -it --rm -v $(pwd):/workspace ghcr.io/oras-project/oras:v1.2.0 \
       manifest fetch registry.kryukov.local/library/files:1.0.0 --pretty
```

## Пример использования volume image

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: sample-volume
  labels:
    app: nginx
    version: 1.27.1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
      version: 1.27.1 
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
      - name: nginx-persistent-storage
        image: 
          reference: registry.kryukov.local/library/files:1.0.0
          pullPolicy: IfNotPresent
      containers:
      - name: nginx
        image: nginx:1.27.1
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-persistent-storage
          mountPath: /usr/share/nginx
```
