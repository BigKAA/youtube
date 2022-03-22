# notes

    
    dnf install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    mkdir /root/rpm
    yumdownloader --assumeyes --destdir=/root/rpm --resolve wget epel-release openssl-libs openssl \
    openssl-devel libsepol-devel device-mapper-libs ebtables openssl curl rsync bash-completion socat unzip \
    python3-setuptools python3-pip python38 python38-libs docker-ce vsftpd createrepo


    mkdir /root/docker-images/

    pip install -r requirements.txt
    cp -r inventory/cluster-5 inventory/cluster-offline
    vim inventory/cluster-offline/group_vars/k8s_cluster/k8s-cluster.yml

local_release_dir: "/root/docker-images/"

    vim inventory/cluster-offline/group_vars/k8s_cluster/addons.yml

registry_enabled: true
metrics_server_enabled: true
metallb_speaker_enabled: true
metallb_ip_range:
   - "192.168.218.180-192.168.218.184"

Скачаем необходимые для установки файлы.

    export ANSIBLE_INVALID_TASK_ATTRIBUTE_FAILED=False
    ansible-playbook -i inventory/cluster-offline/inventory.ini cluster.yml -e download_run_once=true -e download_localhost=true --tags download --skip-tags upload,upgrade

