# k3s де стенд

**Проект временно заморожен**

Домашний стенд разработчика приложений с деплоем в кубер.

**Важно!** Для основной машины (виртуальной машины) потребуется много оперативной памяти.

**Важно!** В качестве основной OS используется клон CentOS 9.

Стенд состоит из двух виртуальных машин: маленькой и большой :)

## Маленькая машина

Ресурсы:

* 1 и более CPU
* 1 и более Gb RAM

Имя машины: `dev-ssh.kryukov.local`

Доступ по ssh для подключения различных сред разработки типа Visual Studio Code. Что бы не настраивать среду разработки
для PC и MAC.

NFS сервер - для поддержки volumes типа ReadWriteMany.

### Пользователь

```shell
useradd artur
password artur
```

```shell
echo "artur ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/artur
```

### Приложения

```shell
systemctl disable firewalld
systemctl stop firewalld
dnf install mc vim nfs-utils tar git 
```

#### NFS server

```shell
mkdir /var/nfs-data
chmod a+x /var/nfs-data
```

```shell
echo -n '/var/nfs-data 192.168.218.0/24(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)' >> /etc/exports
```

```shell
systemctl enable nfs-server
systemctl start nfs-server
```

#### Helm

```shell
wget https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz
tar -zxvf helm-v3.13.3-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/local/bin/helm
helm version
rm -rf helm-v3.10.0-linux-amd64.tar.gz linux-amd64
```

## Большая машина

Основная машина (виртуальная машина) на которой будут размещены все инструменты и среда запуска:

* Приложений CiCd
* Тестируемых приложений.
* Вспомогательных приложений.

Ресурсы:

* 8 и более CPU
* 16 и более Gb RAM

Имя машины: `dev.kryukov.local`

## Приложения

```shell
systemctl disable firewalld
systemctl stop firewalld
dnf install mc vim nfs-utils bind bind-utils httpd-tools
```

### DNS server

Поскольку будет использоваться "левый" домен `kryukov.local`, а kubernetes игнорирует файлы `/etc/hosts`, будем
поднимать собственный DNS.

В файле `/etc/named.conf` исправляем строки:

```
options {
        listen-on port 53 { any; };
        allow-query     { any; };
        recursion yes;
        dnssec-validation no;

zone "kryukov.local" IN {
        type master;
        file "kryukov.local";
}; 
```

```shell
named-checkconf
```

Добавляем файл `/var/named/kryukov.local`.

```
$TTL 1D
@       IN SOA  @ artur.kryukov.biz. (
                2024011200      ; serial
                1D      ; refresh
                1H      ; retry
                1W      ; expire
                3H )    ; minimum
        NS      dev
dev     A       192.168.218.189
dev-ssh A       192.168.218.189

gitlab      IN CNAME dev
registry    IN CNAME dev
pg          IN CNAME dev
minio       IN CNAME dev
argocd-dev  IN CNAME dev
postgre     IN CNAME dev
;;; Тут дальше добавляем имена машин из домена
```

```shell
chgrp named /var/named/kryukov.local
```

```shell
named-checkzone kryukov.local /var/named/kryukov.local
```

```shell
systemctl start named
systemctl status named
systemctl enable named
```

```shell
dig pg.kryukov.local @127.0.0.1
```

В файле сетевого интерфейса `/etc/NetworkManager/system-connections/тут-файл` меняем DNS сервер на локальный.
И рестартуем NetworkManager.

```shell
systemctl restart NetworkManager
```

Если лениво руками править файл `/etc/hosts` на "маленькой" машине, там тоже можно использовать этот DNS сервер.

### k3s

В качестве "карманного" сервера kubernetes будем использовать однодовую установку k3s. С учётом того, что возможно...
возможно в дальнейшем потребуется добавлять дополнительные ноды в кластер.

При установке отключаем инсталляцию ingress controller на базе traefik. Мне он не нравится, я поставлю другой контроллер.

```shell
curl -sfL https://get.k3s.io | K3S_TOKEN='BlahPassword' sh -s - server --cluster-init \
--default-local-storage-path "/var/k3s/storage" --data-dir "/var/k3s/data" --disable=traefik
```

В моем случае, на момент записи видео будет установлена версия `v1.28.5+k3s1` kubernetes.

Наблюдаем за развертыванием кластера.

```shell
watch kubectl get pods -A
```

Скопируем файл `/etc/rancher/k3s/k3s.yaml` на все машины, где вы планируете работать с текущим кластером. Не
забудьте заменить ip адрес с `127.0.0.1` на `192.168.218.189`.

## Установка базовых приложений

Установка описана в [этом документе](install-base-app.md).

## Установка minio

