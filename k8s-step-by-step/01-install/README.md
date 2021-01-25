# Установка кластера

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

