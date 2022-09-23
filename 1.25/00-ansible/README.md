# Ansible playbook для установки кластера k8s

В данный момент поддерживает:
* Установку одной control node.
* Установка несколько control node и HA доступ к API kubernetes.
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

* [Инвентори](hosts.yml).
* [Инвентори HA](hosts-ha.yml).
* [Общая конфигурация](group_vars/k8s_cluster).

## Запуск

### Личное

Если ansible установлен в venv

```bash
. ~/venv/bin/activate
```

K8s с одним мастером:

    ansible-playbook -i hosts.yml install-single-master.yaml

HA с несколькими мастерами:

    ansible-playbook -i hosts-ha.yml install-ha-cluster.yaml

Удалить кластер (-i hosts.yml или -i hosts-ha.yml):

    ansible-playbook -i hosts.yml reset.yaml

