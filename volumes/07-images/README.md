# Images volumes

**Внимание! Работает только с Container runtime, которые поддерживают этот механизм. Например, CRI-O ≥ v1.31.**

В kubernetes v1.31 появился новый тип volume - [image](https://kubernetes.io/docs/concepts/storage/volumes/#image).

> Тома типа image представляют собой объект [OCI](https://github.com/opencontainers/distribution-spec/) (образ контейнера или артефакт), который доступен на хост-компьютере kubelet.

## Создание артефакта в OCI хранилище

Некоторые приложения, например [helm](https://helm.sh/blog/storing-charts-in-oci/#helm) или [ormb](https://github.com/kleveross/ormb), могут самостоятельно создавать артефакты в OCI хранилище. Но если вам потребуется разместить в нём произвольный набор файлов, рекомендую воспользоваться приложением ORAS.

### ORAS

Для создания (и не только) артефактов в OCI хранилище можно использовать приложение [oras](https://oras.land/).

Установка приложения описана в [документации](https://oras.land/docs/installation#linux).

```shell
export VERSION="1.2.0"
curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
mkdir -p oras-install/
tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
sudo mv oras-install/oras /usr/local/bin/
rm -rf oras_${VERSION}_*.tar.gz oras-install/
```

Если вы привыкли к контейнерам, то для вас разработчики создали контейнер с приложением:

```shell
docker run -it --rm -v $(pwd):/workspace ghcr.io/oras-project/oras:v1.2.0 help
```

### Создание артефакта

В качестве примера будем использовать файлы из директории `html`.

У меня свой собственный СА, поэтому приходится при запуске приложения указывать его сертификат.

Грузим артефакт в хранилище:

```shell
export CL_PASS=password
echo $CL_PASS | oras push -u admin --password-stdin --ca-file ca.crt registry-cl.kryukov.local/library/files:1.0.0 ./html/:text/html
```

Проверяем:

```shell
oras manifest fetch --ca-file ca.crt registry-cl.kryukov.local/library/files:1.0.0 --pretty
```

## Пример использования volume image

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: sample-volume
  namespace: default
  labels:
    app: &app nginx
    version: &version 1.27.1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: *app
      version: *version
  template:
    metadata:
      labels:
        app: *app
        version: *version
    spec:
      volumes:
      - name: nginx-persistent-storage
        image: 
          reference: registry-cl.kryukov.local/library/files:1.0.0
          pullPolicy: IfNotPresent
      containers:
      - name: nginx
        image: nginx:1.27.1
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-persistent-storage
          mountPath: /usr/share/nginx
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
          requests:
            memory: "64Mi"
            cpu: "250m"
```
