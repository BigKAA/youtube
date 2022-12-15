# Предварительные действия.

На всех машинах, где будет установлен кластер kubernetes, необходимо:
* Отключить swap.
* Отключить firewall.
* Отключить selinux.
* Настроить параметры ядра.
* Установить приложения.

По поводу selinux. Его можно не отключать, kubernetes и система управления контейнерами умеет его использовать. 

## Отключить swap

В файле `/etc/fstab` закоментируйте строку, определяющую подключение swap пространства.

```shell
swapoff -a
```

## Отключить firewall

```shell
systemctl stop firewalld
systemctl disable firewalld
```

Убедитесь, что в фаерволе нет правил и установлены политики по умолчанию ACCEPT:

```shell
iptables -L -n
iptables -t nat -L -n
iptables -t mangle -L -n
iptables -t raw -L -n 
```

## Отключить selinux

В файле `/etc/selinux/config` установите значение переменной `SELINUX` в `disabled` или, если в дальнейшем
захотите настроить правила selinux, в `permissive`.

```shell
setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

## Настроить параметры ядра

Сначала загрузите модуль `br_netfilter`:

```shell
modprobe br_netfilter
```

Затем добавьте файл `/etc/modules-load.d/modules-kubernetes.conf`:

```
br_netfilter
```

В файл `/etc/sysctl.conf` добавтье следующие строки:

```
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_nonlocal_bind=1
```

Если планируете использовать сети ipv6, добавьте строку:

```
net.bridge.bridge-nf-call-ip6tables=1
```

## Установить приложения.

Добавляем репозиторий kubernetes. Для этого создаём файл `/etc/yum.repos.d/kubernetes.repo`:

```shell
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
async = 1
enabled=1
baseurl = https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
gpgcheck = 1
gpgkey = https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
name = Base programs for k8s
EOF
```

_Приложения устанавливаем, но не запускаем!_

Обязательные:

* bash-completion
* python3
* tar
* containerd
* nfs-utils
* chrony
* kubectl
* kubelet
* kubeadm

```shell
dnf install -y bash-completion python3 tar containerd nfs-utils chrony kubectl kubelet kubeadm
```

Не обязательные:

* mc
* vim
* git
* rsyslog
* jq

```shell
dnf install -y mc vim git rsyslog jq
```

## Запуск необходимых сервисов

### NTP

Включаем NTP. Синхронизация времени на серверах кластера обязательна. Если её не включить возможны проблемы с
сертификатами.

```shell
systemctl enable chronyd
systemctl start chronyd
systemctl status chronyd
```

### syslog

Опционально включаем систему логирования rsyslog. Я предпочитаю смотреть текстовые логфайлы классического syslog, а 
не копаться в бинарниках systemd. Да и потом логи системы будет легче собирать.

```shell
systemctl enable rsyslog
systemctl start rsyslog
systemctl status rsyslog
```

### containerd

Система контейнеризации containerd.

```shell
systemctl enable containerd
systemctl start containerd
systemctl status containerd
```

Добавим конфигурационный файл `/etc/crictl.yaml` для приложения управления контейнерами 
[crictl](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md):

```
runtime-endpoint: "unix:///run/containerd/containerd.sock"
image-endpoint: "unix:///run/containerd/containerd.sock"
timeout: 0
debug: false
pull-image-on-create: false
disable-pull-on-run: false
```

Проверим работоспособность утилиты:

```shell
crictl images
crictl ps -a
```

_Ещё одни интересный документ про [crictl](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/)_

## Немного автоматизации

Ansible [prepare-hosts.yaml](https://github.com/BigKAA/00-kube-ansible/blob/main/services/prepare-hosts.yaml)