# Ansible playbook для установки кластера k8s

В данный момент поддерживает:
* Установку одной или несколько control nodes.
* HA доступ к API kubernetes.
* containerd.
* calico.

Не оттестировано на дистрибутивах Debian.

## Установка ansible

Так получилось, что у меня в WSL2 стоит Ubuntu:

```shell
apt install python3.10-venv
python3 -m venv venv
. ~/venv/bin/activate
python3 -m pip install ansible
```

Генерируем ssh ключ:

```shell
ssh-keygen
```

Копируем ключики в виртуальные машины из [hosts.yaml](hosts.yml):

 ```shell
ssh-copy-id root@control1.kryukov.local
ssh-copy-id root@control2.kryukov.local
ssh-copy-id root@control3.kryukov.local
ssh-copy-id root@worker1.kryukov.local
ssh-copy-id root@worker2.kryukov.local
ssh-copy-id root@worker3.kryukov.local
ssh-copy-id root@db1.kryukov.local
```

## Конфигурационные параметры

* [Инвентори](hosts.yaml).
* [Общая конфигурация](group_vars/k8s_cluster).

## Установка

### k8s с одной control node.

В [инвентори](hosts.yaml) в группе `k8s_masters` необходимо указать только один хост.

    ansible-playbook install-cluster.yaml

### k8s с несколькими control nodes.

В [инвентори](hosts.yaml) в группе `k8s_masters` необходимо указать **нечётное количество
control nodes**.

    ansible-playbook install-cluster.yaml

### k8s c HA.

Используются haproxy и keepalived.

В конфигурационнм файле определите параметры доступа к API :

* `ha_cluster_virtual_ip` - виртуальный IP адрес.
* `ha_cluster_virtual_port` - порт. Не должен быть равен 6443.

## Удалить кластер

    ansible-playbook reset.yaml