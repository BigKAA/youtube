docker_install
=========

Установка последней версии docker CE.

Дополнительно устанавливает пакеты: tc, ipvsadm и network-scripts

Отключает NetworkManager.

Example Playbook
----------------

    - name: Install docker and k8s packages
      hosts: k8s_cluster
      become: yes
    
      roles:
        - docker_install

License
-------

GPL v2
