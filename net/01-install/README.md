# Установка кластера.

Да, мы опять ставим кластер. Но на сей раз сделаем "упор" на сети. В качестве соновной сети будем использовать
[Project calico](https://www.projectcalico.org/).

Кластер будет устанавливаться на машины с CentOS 8.

## Подготовка.

На всех машинах кластера отключаем:
* swap.
* SELinux.
* Firewall.

### Устанавливаем докер

```shell script
chmod +x 00-install-docker-ce8.sh
./00-install-docker-ce8.sh
docker version
```

### Установка кубернетес

#### Мастер нода.

```shell script
chmod +x 01-install-k8s-ce8.sh
./01-install-k8s-ce8.sh
```

Тестовый запуск установки, ищем ошибки.

```shell script
kubeadm init --config kube-config.yaml --dry-run | less
```

Если все хорошо - устанавливаем мастер ноду.

```shell script
kubeadm init --config kube-config.yaml
```

Смотрим что получилось

```shell script
kubectl  get nodes
NAME                       STATUS     ROLES    AGE     VERSION
ip-218-161.kryukov.local   NotReady   master   2m32s   v1.19.3
```

#### Worker нода

```shell script
chmod +x 00-install-docker-ce8.sh
./00-install-docker-ce8.sh
docker version
chmod +x 01-install-k8s-ce8.sh
./01-install-k8s-ce8.sh
```

На мастер ноде получаем токен для подключения к кластеру worker ноды.

```shell script
kubeadm token create --print-join-command
```

Запускаем установку. Токены берем из вывода предыдущей команды.

```shell script
kubeadm join 192.168.218.161:6443 --token uctr1t.w80eup2o7v19r9xf \
  --discovery-token-ca-cert-hash sha256:7f141f014028fed38611479249f7a744a183bde100afe141ee937967693db739
```

Смотрим что получилось.

```shell script
kubectl get nodes
NAME                       STATUS     ROLES    AGE   VERSION
ip-218-161.kryukov.local   NotReady   master   66s   v1.19.3
ip-218-162.kryukov.local   NotReady   <none>   18s   v1.19.3
```

Видим, что DNS не запустился из-за отсутствия настроенной сети внутри кластера.
