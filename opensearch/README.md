# Opensearch

[Documentations](https://opensearch.org/docs/latest/)


## Сертификаты.

Для работы с сертификатами будем использовать [cert-manager](https://cert-manager.io).

Создаём:
* Свой СА.
* Сертификат для нод. Один на все ноды. Но можно один для группы нод.
* Клиентский сертификат для админа кластера. 

Все манифесты [тут](manifests/certs.yaml)

**Внимание!** Обычно ```cert-manager``` запускается без параметра ```--enable-certificate-owner-ref=true```.
Поэтому после удаления сертификатов сикреты с сертификатами не удаляются.
    
## Пароли

Первоначальные пользователи и их пароли создаются в файле 
[opensearch-internal-users.yaml](manifests/opensearch-internal-users.yaml)

Хеши паролей можно генерировать при помощи программы ```mkpasswd```.

Установить ```mkpasswd``` в Ubuntu

```shell
sudo apt install whois
```

в Centos

```shell
sudo dnf install mkpasswd
```

```shell
mkpasswd -m help
```

Генерация пароля:

```shell
mkpasswd -m bcrypt-a
```

## Charts

### Install

```shell
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update
```

```shell
helm search repo opensearch
```

Сначала добавим необходимые для работы сертификаты и сикреты. 

**Внимание!** Если в namespace присутствуют сикреты с сертификатами, при добавлении сертификатов в cert-manager, 
использующие эти сикреты, данные в сикретах не обновляются.

```shell
kubectl create ns es
kubectl apply -f manifests
```

**Внимание!** Если вы уже устанавливали приложения, скорее всего в кластере уже есть PVC используемые приложениями.
В этом случае данные о пользователях, ролях и прочих сущностях, находящихся в сикретах применяться не будут.
Если вы хотите установить приложения "с нуля", удалите PVC. 

Установка мастер подов:

```shell
cd charts
helm install master opensearch/opensearch -f values-master.yaml -n es
```

Установка data и ingest подов.

```shell
cd charts
helm install data opensearch/opensearch -f values-data.yaml -n es
```

Установка dashboards

```shell
cd charts
helm install dashboard opensearch/opensearch-dashboards -f values-dashboard.yaml -n es
```

### Uninstall

```shell
helm uninstall dashboard -n es
helm uninstall data -n es
helm uninstall master -n es
kubectl delete -f manifests
```

### Проверка работоспособности

```shell
curl -XGET  https://esapi.kryukov.local/ -u 'admin:password' --insecure
```

## Внутренности

Управление модулем security внутри контейнера. Подробности о приложении ```securityadmin.sh``` смотрите в
[документации](https://opensearch.org/docs/latest/security-plugin/configuration/security-admin).

```shell
./securityadmin.sh -cd ../../../config/opensearch-security/ -icl -nhnv -cacert ../../../config/admin/ca.crt \
-cert ../../../config/admin/tls.crt \
-key ../../../config/admin/tls.key
```

## Видео

[<img src="https://img.youtube.com/vi/dXfOpp53X58/maxresdefault.jpg" width="50%">](https://youtu.be/dXfOpp53X58)
