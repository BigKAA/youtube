# Upgrade cluster

**Перед обновлением версии кластера**:

* Обновление возможно только на следующую минорную версию или на патч версию.
  Например, что бы обновиться с 1.23.x до 1.25.x необходимо сначала обновиться
  до версии 1.24.x и только потом до 1.25.x. Обновляться с одной патч версии
  до другой можно в произвольной последовательности. Например, с 1.25.0 
  сразу до 1.25.4.
* Обязательно прочтите [Changelog](https://kubernetes.io/releases/) 
  версии на которую вы хотите обновиться. Велика вероятность, что в 
  новой версии удалена поддержка каких либо API или у них изменена
  версия.
* Поставьте где нибудь тестовый кластер с новой версией kubernetes. И там 
  проверьте все ваши манифесты, helm charts, процедуры CI|CD. Не факт, что
  всё это будет работать в новой версии кластера.

Обновление версии кластера, [документация](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/).

## План

Последовательность простая.

1. Обновляем первую control ноду. Все остальные ноды будут получать необходимые
   параметры из первой ноды.
2. Обновляем остальные контрол ноды.
3. Обновляем worker ноды.

Не обновляйте ноды кластера одновременно. 

## Обновление первой control ноды

1. Обновите приложения `kubeadm`, `kubelet` и `kubectl` до необходимой версии.

Например, в RedHat совместимом дистрибутиве.

```shell
dnf update kubelet-1.25.4-0.x86_64 -y
dnf update kubectl-1.25.4-0.x86_64 -y
dnf update kubeadm-1.25.4-0.x86_64 -y
```

2. Запустите процедуру очистки (миграции приложений) этой ноды.

```shell
kubectl drain ИМЯ_НОДЫ --ignore-daemonsets
```

3. Обновите ноду.

```shell
kubeadm upgrade apply v1.25.4 -y
```

Обновление ноды достаточно длительная процедура.

4. Обязательно перезапустите kubelet.

```shell
systemctl restart kubelet
systemctl status kubelet
```

5. В заключении разрешите планировщику размещать на ноде новые поды.

```shell
kubectl uncordon ИМЯ_НОДЫ
kubectl get nodes
```

## Обновление остальных control нод

1. Обновите приложения `kubeadm`, `kubelet` и `kubectl` до необходимой версии.

Например, в RedHat совместимом дистрибутиве.

```shell
dnf update kubelet-1.25.4-0.x86_64 -y
dnf update kubectl-1.25.4-0.x86_64 -y
dnf update kubeadm-1.25.4-0.x86_64 -y
```

2. Запустите процедуру очистки (миграции приложений) этой ноды.

```shell
kubectl drain ИМЯ_НОДЫ --ignore-daemonsets
```

3. Обновите ноду.

```shell
kubeadm upgrade node
```

Обновление ноды достаточно длительная процедура.

4. Обязательно перезапустите kubelet.

```shell
systemctl restart kubelet
systemctl status kubelet
```

5. Разрешите планировщику размещать на ноде новые поды.

```shell
kubectl uncordon ИМЯ_НОДЫ
kubectl get nodes
```

## Обновление worker нод

1. Обновите приложения `kubeadm`, `kubelet` и `kubectl` до необходимой версии.

Например, в RedHat совместимом дистрибутиве.

```shell
dnf update kubelet-1.25.4-0.x86_64 -y
dnf update kubectl-1.25.4-0.x86_64 -y
dnf update kubeadm-1.25.4-0.x86_64 -y
```

2. Запустите процедуру очистки (миграции приложений) этой ноды.

На control ноде

```shell
kubectl drain ИМЯ_НОДЫ --ignore-daemonsets
```

3. Обновите ноду.

```shell
kubeadm upgrade node
```

Обновление ноды достаточно длительная процедура.

4. Обязательно перезапустите kubelet.

```shell
systemctl restart kubelet
systemctl status kubelet
```

5. Разрешите планировщику размещать на ноде новые поды.

На control ноде:

```shell
kubectl uncordon ИМЯ_НОДЫ
kubectl get nodes
```

## Немного автоматизации.

Я не проверял эти плейбуки на боевых серверах! Используйте их на свой
страх и риск.

[Собственно плейбук](https://github.com/BigKAA/00-kube-ansible/blob/main/upgrade.yaml).

