# Starter

Подготовка сервера, который в дальнейшем будет использоваться для offline установки
кластеров kubernetes при помощи kubespray.

## raw hub

## rpm hub

    curl -v --user 'docker-user:password' --upload-file ./test.rpm http://nexus.kryukov.local/repository/rpm/test.rpm

```
[nexusrepo]
name=Nexus Repository
baseurl=http://nexus.kryukov.local/repository/rpm/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
repo_gpgcheck=0
priority=1
```

    mkdir ~/rpms
    yumdownloader --assumeyes --destdir=rpms --resolve device-mapper-persistent-data
    yumdownloader --assumeyes --destdir=rpms --resolve lvm2
    yumdownloader --assumeyes --destdir=rpms --resolve docker-ce


    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
    enabled=1
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
    EOF

     yumdownloader --assumeyes --destdir=rpms --resolve yum-utils kubeadm-1.23.* kubelet-1.23.* kubectl-1.23.* ebtables    

Список rpm пакетов

## docker hub

На этом сервере должен быть установлен hub, где будет храниться базовый набор контейнеров и приложений kubernetes.

https://hub.docker.com/r/sonatype/nexus3/

Получаем пароль адмиина nexus

    docker exec -it nexus cat /nexus-data/admin.password

Настраиваем хранилище контейнеров в nuxus. Добавляем пользователя docker-user с паролем password

Обратите внимание на то, что у нас леый ca. Соотвественно надо настроить docker engine там где вы собираете и
пушите образы.

Логинимся в наш хаб.

    docker login --username=docker-user --password=password starter.kryukov.local

Дальше пушим образ.

## Подготовка бинарников и образов контейнеров

    git clone
    cd kubespray
    pip3 install ruamel.yaml
    declare -a IPS=(192.168.218.178)
    CONFIG_FILE=inventory/cluster-offline/hosts.ini /usr/bin/python3 contrib/inventory_builder/inventory.py ${IPS[@]}
    mkdir /root/docker-images/
    vim inventory/cluster-offline/group_vars/k8s_cluster/k8s-cluster.yml

local_release_dir: "/root/docker-images/"

    ssh-keygen
    ssh-copy-id starter.kryukov.local

    pip3 install -r requirements.txt
    ansible-playbook -i inventory/cluster-offline/inventory.ini cluster.yml -e download_run_once=true \
    -e download_localhost=true     --tags download --skip-tags upload,upgrade

Получаем ошибку. В скачанных бинарниках ищем архив containerd-*.tgz из него вытаскиваем приложение ctr в
/usr/local/bin

    mkdir -p /tmp/kubespray_cache/images

Повторно запускаем ansible-playbook.

    mkdir /root/k8s-images
    mv /tmp/kubespray_cache/images/* /root/k8s-images

так же потребуются

    /root/docker-images/kubeadm-*-amd64 config images list

```bash
#!/usr/bin/env bash

for I in $(/root/docker-images/kubeadm-*-amd64 config images list); do
  echo ========================
  echo $I
  nerdctl pull $I
  ARCHIVE=$(echo $I | tr \/ _  | tr \: _ )
  nerdctl save $I -o $ARCHIVE.tar
  nerdctl rmi $I
done
mv -f k8s.gcr.*.tar /root/k8s-images
```
 Download image if required

- name: Set image save/load command for containerd
  set_fact:
    image_save_command: "{{ bin_dir }}/nerdctl -n k8s.io image save -o {{ image_path_final }} {{ image_reponame }}"
    image_load_command: "{{ bin_dir }}/nerdctl -n k8s.io image load < {{ image_path_final }}"
  when: container_manager == 'containerd'

- name: Set image save/load command for containerd on localhost
  set_fact:
    image_save_command_on_localhost: "{{ containerd_bin_dir }}/ctr -n k8s.io image export --platform linux/{{ image_arch }} {{ image_path_cached }} {{ image_reponame }}"
  when: container_manager_on_localhost == 'containerd'
