# k3s для разработчиков

## Локальное хранилище

Или Local Path Provisioner.
[Конфигурация хранилища](https://github.com/rancher/local-path-provisioner/blob/master/README.md#configuration)

Текущую конфигурацию можно посмотреть в ConfigMap ```local-path-config```. Нас интересует файл ```config.json```,
где перечислены ноды кластера и директории, которые будут предоставляться Local Path Provisioner. 

```shell
k3s kubectl -n kube-system get cm local-path-config -o=jsonpath='{.data.config\.json}'
```

Пример создания PVC - файл [01-pvc.yaml](manifests/01-pvc.yaml).

```shell
k3s kubectl apply -f manifests/01-pvc.yaml
```

Посмотрим состояние PVC.

```shell
k3s kubectl get pvc
```

_Находится в состоянии Pending до тех пор, пока в кластере не появится приложение, использующее данный PVC._

Запустим приложение:

```shell
k3s kubectl apply -f manifests/02-deployment.yaml
```

Смотрим содержимое директории (по умолчанию) ```/var/lib/rancher/k3s/storage/``` и наблюдаем там
директорию ```pvc-*_default_nginx-pv```. Внутри которой будут два файла, созданные в init контейнере пода.

## Доступ к приложению

Задача вывести приложение за пределы кластера.

### NodePort

Классический сервис типа [NodePort](manifests/03-nodeport.yaml).

```shell
k3s kubectl apply -f manifests/03-nodeport.yaml
```

### LoadBalancer

k3s "из коробки" предоставляет сервис типа [LoadBalancer](manifests/04-loadbalancer.yaml).
_Для предоставления сервиса используется Traefik._

Используем порт 8080, поскольку порты 80 и 443 на данный момент заняты ингресс контроллером.

```shell
k3s kubectl apply -f manifests/04-loadbalancer.yaml
```

### Ingress

Ingress контроллер [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-ingress/) использует порты 80 и 443.

[Ingress](manifests/05-ingress.yaml) универсальный, без указания имени хоста.

```shell
k3s kubectl apply -f manifests/05-ingress.yaml
```

## Helm controller

В k3s установлен [helm-controller](https://github.com/k3s-io/helm-controller).

[Манифест для helm контроллера](manifests/06-s3-helm.yaml), запускающий minio в кластере.

```shell
k3s kubectl apply -f manifests/06-s3-helm.yaml
```

Удаление чарта minio: 

```shell
k3s kubectl delete -f manifests/06-s3-helm.yaml
```

## Автоматический деплоймент

Скопируйте манифесты, которые должны автоматически устанавливаться в директорию: 
```/var/lib/rancher/k3s/server/manifests```.

## Видео

* Youtube: https://youtu.be/3GPAOJSKvdo
* VK: https://vk.com/video7111833_456239205
* Телеграмм: https://t.me/arturkryukov/67