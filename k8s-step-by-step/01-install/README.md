# Установка кластера

На примере CentOS 7.

## 00 - подготовительные действия

На машине master запустить DNS сервер с зоной прямого преобразования "kryukov.local":

    $TTL 86400
    @ IN SOA master.kryukov.local. artur.kryukov.biz. (
                                                2021012100 ;Serial
                                                3600 ;Refresh
                                                1800 ;Retry
                                                604800 ;Expire
                                                86400 ;Minimum TTL
    )
    
    @ IN NS master
    
    master          IN      A       192.168.218.170
    control1        IN      A       192.168.218.171
    control2        IN      A       192.168.218.172
    control3        IN      A       192.168.218.173
    
    worker1         IN      A       192.168.218.174
    worker2         IN      A       192.168.218.175
    worker3         IN      A       192.168.218.176

и зоной обратного преобразования "218.168.192.in-addr.arpa".

    $TTL 86400
    @ IN SOA master.kryukov.local. artur.kryukov.biz. (
                                                2021012100 ;Serial
                                                3600 ;Refresh
                                                1800 ;Retry
                                                604800 ;Expire
                                                86400 ;Minimum TTL
    )
    @ IN NS master.kryukov.local.
    
    170 IN PTR master.kryukov.local.
    
    171     IN      PTR     control1.kryukov.local.
    172     IN      PTR     control2.kryukov.local.
    173     IN      PTR     control3.kryukov.local.
    
    174     IN      PTR     worker1.kryukov.local.
    175     IN      PTR     worker2.kryukov.local.
    176     IN      PTR     worker3.kryukov.local.

Сгенерировать, если его ещё нет, ssh ключ:

    ssh-keygen

Установить ssh ключ на машины кластера.

    ssh-copy-id control1
    ssh-copy-id control2
    ssh-copy-id control3
    ssh-copy-id worker1
    ssh-copy-id worker2
    ssh-copy-id worker3

Переходим в директорию 00-ansible.

Проверяем подключение ansible к хостам:

    ansible-playbook ping.yaml

Если ping не проходит, ищем ошибки и исправляем.

Приводим настройки серверов кластера к одному виду:

    ansible-playbook prepare-hosts.yaml

## Kubespray

    git clone https://kubernetes.io/docs/setup/production-environment/tools/kubespray/
    cd kubespray/inventory
    cp sample cluster
    cd cluster

Параметры смотрим [тут](01-kubespray/README.md).

Переходим в корень kubespray и запускаем установку кластера. Для этого в системе должны быть установлены интерпретатор 
python и pip.

    pip install -r requirements.txt
    ansible-playbook -i inventory/cluster/inventory.ini cluster.yml

После установки на ноде control1 можно посмотреть состояние кластера.

    kubectl get nodes -o wide
    NAME                     STATUS   ROLES                  AGE   VERSION   INTERNAL-IP       EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
    control1.kryukov.local   Ready    control-plane,master   25m   v1.20.2   192.168.218.171   <none>        CentOS Linux 7 (Core)   3.10.0-1160.11.1.el7.x86_64   containerd://1.3.9
    control2.kryukov.local   Ready    control-plane,master   25m   v1.20.2   192.168.218.172   <none>        CentOS Linux 7 (Core)   3.10.0-1160.11.1.el7.x86_64   containerd://1.3.9
    control3.kryukov.local   Ready    control-plane,master   24m   v1.20.2   192.168.218.173   <none>        CentOS Linux 7 (Core)   3.10.0-1160.11.1.el7.x86_64   containerd://1.3.9
    worker1.kryukov.local    Ready    <none>                 22m   v1.20.2   192.168.218.174   <none>        CentOS Linux 7 (Core)   3.10.0-1160.11.1.el7.x86_64   containerd://1.3.9
    worker2.kryukov.local    Ready    <none>                 22m   v1.20.2   192.168.218.175   <none>        CentOS Linux 7 (Core)   3.10.0-1160.11.1.el7.x86_64   containerd://1.3.9
    worker3.kryukov.local    Ready    <none>                 13m   v1.20.2   192.168.218.176   <none>        CentOS Linux 7 (Core)   3.10.0-1160.11.1.el7.x86_64   containerd://1.3.9

Для просмотра контейнеров на ноде, вместо docker следует использовать crictl

    crictl ps
    CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID
    1097d550bb381       43154ddb57a83       15 minutes ago      Running             kube-proxy                0                   a5bda83433ae1
    47baed40e7ae9       ed2c44fbdd78b       15 minutes ago      Running             kube-scheduler            0                   512d577e92ad5
    ccc6233675992       a27166429d98e       15 minutes ago      Running             kube-controller-manager   0                   4f6fa61c307dc
    9d88053806de9       90f9d984ec9a3       23 minutes ago      Running             node-cache                0                   f7d86f788f4eb
    74c2eb6a0a4a6       cb12d94b194b3       23 minutes ago      Running             calico-node               0                   794808481e7ae
    c38354995b6d0       a8c2fdb8bf76e       26 minutes ago      Running             kube-apiserver            0                   55baeed8da067
    bee1356874171       d1985d4043858       26 minutes ago      Running             etcd                      0                   b43a297393ef9

    crictl pods
    POD ID              CREATED             STATE               NAME                                             NAMESPACE           ATTEMPT             RUNTIME
    a5bda83433ae1       15 minutes ago      Ready               kube-proxy-xbqkc                                 kube-system         0                   (default)
    512d577e92ad5       15 minutes ago      Ready               kube-scheduler-control1.kryukov.local            kube-system         0                   (default)
    4f6fa61c307dc       15 minutes ago      Ready               kube-controller-manager-control1.kryukov.local   kube-system         0                   (default)
    f7d86f788f4eb       23 minutes ago      Ready               nodelocaldns-szggp                               kube-system         0                   (default)
    794808481e7ae       23 minutes ago      Ready               calico-node-kxlpj                                kube-system         0                   (default)
    55baeed8da067       27 minutes ago      Ready               kube-apiserver-control1.kryukov.local            kube-system         0                   (default)
    b43a297393ef9       27 minutes ago      Ready               etcd-control1.kryukov.local                      kube-system         0                   (default)

    crictl --help

Установите в bash автодополнение для команд kubectl:

    source <(kubectl completion bash)
    echo "source <(kubectl completion bash)" >> ~/.bashrc

## Видео

[<img src="https://img.youtube.com/vi/g9nPFS6dF50/maxresdefault.jpg" width="50%">](https://www.youtube.com/watch?v=g9nPFS6dF50)