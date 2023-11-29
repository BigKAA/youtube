# Gitflic Helm Chart

Создан на основе документации https://docs.gitflic.space/setup/docker_setup. _То, что у них было написано про
kubernetes https://docs.gitflic.space/setup/kuber_setup - не работает из коробки._

## Сборка контейнера

По какой-то причине разработчики не предоставляют готового контейнера приложения. Поэтому вы сами должны его собрать и
куда то положить.

Скачайте [архив последнего релиза](https://gitflic.ru/project/gitflic/gitflic/release) и распакуейте его.

Перенесите [Dockerfile](Dockerfile) в корень проекта.

Запустите сборку контейнера. Имя и тег контейнера задайте согласно вашего хранилища контейнеров.

```shell
docker build -t bigkaa/gitflic:2.16.1 .
docker push bigkaa/gitflic:2.16.1
```

**Внимание!** Контейнер `bigkaa/gitflic:2.16.1` будет удалён после съемки видео.

## Подготовка

### ssh

Для доступа по ssh необходимо включить ssh Service типа NodePort или LoadBalancer.
**Доступ к ssh через Ingress controller не предусмотрен**.

В файле values предусмотрены соответствующие параметры:

```yaml
serviceSSH:
  enable: false
  port: 2222
  # Services type: NodePort or LoadBalancer
  type: NodePort
  # Для сервиса типа NodePort - это обязательный параметр
  nodePort: "31222"
  name: ""
```

Так же, перед установкой helm chart обязательно добавьте Secret, содержащий приватный ssh ключ:

```shell
ssh-keygen -t ed25519 -f key.pem
kubectl -n NAMESPACE create secret generic sshKey --from-file=key.pem --from-file=key.pem.pub 
```

Создание Secret с ключём, является обязательным условием для запуска приложения. Даже если
вы не будете пользоваться доступом по ssh 

## Helm

### Непонятки

1. Приложение можно сконфигурировать через конфигурационный файл или через переменные среды окружения.

С переменными среды окружения не всё ясно. Нет документации или исходных кодов. Поэтому
будем использовать конфигурационный файл и ConfigMap.

2. Директория и файл сертификата для ssh подключений.

В переменных среды окружения есть переменный отдельно для директории, отдельно для
файла сертификата. В конфигурационном файле только файл сертификата.

Переменные среды окружения удалим, но создадим отдельный volume для директории
/opt/gitflic/var/cert/. Потом, после первого запуска и подключения по ssh посмотрим,
нужен ли этот отдельный volume.

3. Судя по всему, gitflic - это монолитное приложение.

Во всяком случае я нигде не видел упоминания о том, что есть возможность горизонтального
масштабирования приложения. Ну и косвенные данны по монтированию volumes говорят о
монолитности.

Поэтому будем делать только одну реплику и только StatefulSet.