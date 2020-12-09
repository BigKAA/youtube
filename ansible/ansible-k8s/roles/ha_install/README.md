ha_install
=========

Устанавливает и настраивает haproxy и keepalived на мастер нодах кластера.

Requirements
------------

Необходимо минимум три мастер ноды.

Role Variables
--------------

ha_install_control_servers - параметры серверов:
* ip - адрес мастер ноды, на которой слушает запросы API сервер. Порт 6443 безальтернативный.
* name - название ноды.
* prioity - приоритет ноды для keepalived

ha_insatll_control_cluster_ip - кластерный ip доступа к API серверу кубеонетес. Порт 7443 
безальтернативный.

    ha_install_control_servers:
       - ip: 192.168.218.171
         name: control1
         priority: 150
       - ip: 192.168.218.172
         name: control2
         priority: 120
       - ip: 192.168.218.173
         name: control3
         priority: 100
    
    ha_insatll_control_cluster_ip: 192.168.218.179


Example Playbook
----------------

    - name: Install HA for k8s API access and vrrl on control plane servers
      hosts: k8s_controls
      become: yes
    
      roles:
        - ha_install

License
-------

GPL v.2

