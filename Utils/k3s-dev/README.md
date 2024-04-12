# Среда разработки на базе kubernetes

Для разработки достаточно сделать однонодовый кластер kubernetes. Где он будет располагаться не важно. В моём случае это будет виртуальная машина 8CPU 16Gb RAM.

## Планируемые приложения

Все необходимые для разработки приложения планируется размешать к kubernetes.

В качестве дистрибутива kubernetes будет использоваться k3s.

Планируемые приложения:

- Gitlab.
- Gitlab runner.
- Harbor.
- Контейнер с инструментами разработчика.
  - Доступ по ssh.
  - Домашняя директория пользователя смонтирована как внешний том.
  - Установленные инструменты разработчика (компиляторы, доп утилиты) в домашнюю директорию пользователя.
- База данных PostgreSQL без кластера.
- Minio.
- ArgoCD.

## Операционная система

В качестве OS для виртуальной машины используется Rocky Linux 9.

Приложения устанавливает по своему желанию. Непосредственно на этой виртуальной машине разработчики работать не будут.

Обязательным к установке является DNS сервер. Он будет использоваться для поддержки внутренних доменов типа local и т.п.

### DNS сервер

```shell
dnf install bind bind-utils -y
```

В файле `/etc/named.conf` вносим следующие изменения:

```text
options {
        listen-on port 53 { any; };
        recursion yes;
        dnssec-validation no;
};        
zone "kryukov.local" IN {
        type master;
        file "kryukov.local";
};        
```

Файл `/var/named/kryukov.local`:

```zone
$TTL 1D
@       IN SOA  @ artur.kryukov.biz. (
                2024021200      ; serial
                1D      ; refresh
                1H      ; retry
                1W      ; expire
                3H )    ; minimum
        NS      dev
dev     A       192.168.218.189 ; это ip виртуальной машины с kubernetes
gitlab      IN CNAME dev
registry    IN CNAME dev
pg          IN CNAME dev
minio       IN CNAME dev
argocd-dev  IN CNAME dev
postgre     IN CNAME dev
```

Применяем конфигурационные файлы:

```shell
named-checkconf
named-checkzone kryukov.local /var/named/kryukov.local
systemctl start named
systemctl enable named
```

Заменяем IP адрес DNS в клиенте.

```shell
sed -i -e 's/^dns=.*/dns=192.168.218.189\;/' /etc/NetworkManager/system-connections/ens33.nmconnection
systemctl restart NetworkManager
```

Проверяем работоспособность клиента DNS:

```shell
cat /etc/resolv.conf
dig mail.ru
dig dev.kryukov.local
```

## k3s

k3s будем ставить в варианте с одной нодой. Мы не предусматриваем дальнейшего расширения
кластера. Если будем использовать много нод, придётся возиться с сетевой файловой системой, которую желательно вынести на отдельный сервер. В общем, многонодовый кластер для разработки - это отдельная песня для команды разработчиков.

Вместо встроенного ingress controller на базе traefik, будем использовать более привычный на базе nginx.

```shell
curl -sfL https://get.k3s.io | sh -s - server --default-local-storage-path "/var/k3s/storage" --data-dir "/var/k3s/data" --disable=traefik
```

```shell
watch kubectl get pods -A
```

Не забудьте скопировать файл `/etc/rancher/k3s/k3s.yaml` на машины, где вы планируете
обращаться к кластеру k3s.

Кластер установлен.

## Установка приложений

[Установка приложений](k3s-application.md).

## Контейнер разработчика

[Контейнер разработчика](ws.md).
