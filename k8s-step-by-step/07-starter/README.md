# Установка кластера kubernetes offilne

**Демо (скрипты и прочее) тестировалось на master ветке kubespray для установки кластера версии 1.23.5! Все плейбуки 
написаны по быстрому и раcчитаны на OS семейства RedHat 8.x**

Предположим, что нам необходимо развернуть кластер kubernetes в ЦОД, в котором закрыт прямой выход в Internet.

Установка кластера kubernetes offline при помощи kebespray требует несколько подготовительных этапов.

1. Подготовка файлов приложений и образов контейнеров.
2. Создание в "закрытом контуре" хранилища файлов и контейнеров. Перенос файлов и контейнеров в хранилище.
3. Настройка kubespray на использование хранилища.

В нашем тестовом варианте подготовка файлов приложений, образов контейнеров и развёртывание хранилища
будет производиться на одном и том же сервере: starter.kryukov.local

В DNS, отвечающем за зону kryukov.local, добавлены две машины starter и nexus. Где nexus - это запись CNAME,
ссылающаяся на машину starter.

Для быстрой установки будет использоваться ansible. Файлы плейбуков находятся в директории 00-ansible.
Плейбук prepare-hosts.yaml разворачивает всё необходимое для дальнейшей работы на машине starter.
* Устанавливает необходимое ПО.
* Создаёт certificate authority. При помощи которого будут подписаны некоторые сертифкаты для вспомогателных
приложений.
* Устанавливает docker.
* Устанавливает Nexus и nginx, выполняющий функцию reverse proxy.

После запуска плейбука необходимо зайти в nexus и настроить два хранилища:
* files, типа raw hosted. Для сохранения файлов приложений.

![](images/files_raw.jpg)

* doker-hub, типа docker hosted. Для хранения образов контейнеров:

![](images/docker-hub.jpg)

Так же добавим роль:

![](images/role.jpg)

И пользователя:

![](images/user.jpg)

Для упрощения работы, установим ему пароль password.

## 1. Подготовка файлов приложений и образов контейнеров.

Для скачивания базового набора мы можем воспользоваться возможностями kubespray. 

Подготовим виртуальную среду для kubespray.

    mkdir kubenv && cd kubenv 
    python3 -m venv env
    source env/bin/activate
    cd

Клонируем kubespray.

    git clone https://github.com/kubernetes-sigs/kubespray.git
    cd kubespray

Отредактируйте файлы inventory так, как если бы вы устанавливали кластер kubernetes.

    cp -r inventory/sample inventory/cluster-offline 

Подготовим директорию, куда будут скачаны файлы приложений.

    mkdir /root/docker-images/
    vim inventory/cluster-offline/group_vars/k8s_cluster/k8s-cluster.yml

В файле изменим параметр: `local_release_dir: "/root/docker-images/"`

Отредактируем inventory:

```ini
[all]
starter.kryukov.local ansible_host=192.168.218.178
[kube_control_plane]
starter.kryukov.local
[etcd]
starter.kryukov.local
[kube_node]
starter.kryukov.local
[calico_rr]
[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr 
```

Сгенерируем ssh ключ и скопируем его на этот же сервер:

    ssh-keygen
    ssh-copy-id starter.kryukov.local

Установим необходимые зависимости:

    pip3 install -r requirements.txt
    
Запустим процедуру скачивания:

    ansible-playbook -i inventory/cluster-offline/inventory.ini cluster.yml -e download_run_once=true \
    -e download_localhost=true --tags download --skip-tags upload,upgrade

Получаем ошибку. В скачанных бинарниках в директории `/root/docker-images/` ищем архив `containerd-*.tgz` из него 
вытаскиваем приложение `ctr` в `/usr/local/bin`.

Создаём директорию, куда будут помещены файлы образов контейнеров:

    mkdir -p /tmp/kubespray_cache/images

Повторно запускаем ansible-playbook.

    ansible-playbook -i inventory/cluster-offline/inventory.ini cluster.yml -e download_run_once=true \
    -e download_localhost=true --tags download --skip-tags upload,upgrade

Создаём директорию, где будут храниться образы контейнеров и переносим в неё файлы из временной директории:

    mkdir /root/k8s-images
    mv /tmp/kubespray_cache/images/* /root/k8s-images

Ещё нам потребуются контейнеры, список которых выдаст kubeadm. Эти контейнеры kubespray по умолчанию не скачивает.

    /root/docker-images/kubeadm-*-amd64 config images list

При помощи скрипта [load-i.sh](00-ansible/roles/prepare-hosts/files/load-i.sh) создадим недостающий файлы образов.

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
# Кое что приходится фиксить руками для kubespray :( 
nerdctl pull quay.io/coreos/etcd:v3.5.1
nerdctl save quay.io/coreos/etcd:v3.5.1 -o /root/k8s-images/quay.io_coreos_etcd_v3.5.1.tar
nerdctl rmi quay.io/coreos/etcd:v3.5.1

mv -f k8s.gcr.*.tar /root/k8s-images
```

Необходимые для установки файлы находятся в двух директориях: `/root/k8s-images` и `/root/docker-images/`. Перенесите 
их на сервер, где будет установлено хранилище файлов.

## 2. Создание в "закрытом контуре" хранилища файлов и контейнеров. Перенос файлов и контейнеров в хранилище.

В нашем случае хранилище файлов находится там же, где мы собирали необходимые файлы. Поэтому нам достаточно залить
файлы в наш nexus.

Мы воспользуемся двумя скриптами:
* [tags.sh](00-ansible/roles/prepare-hosts/files/tags.sh)
  * Поместит образы контейнеров из файлов контейнеров в docker на текущей машине.
  * Добавит контейнерам необходимые теги.
  * Зальёт контейнеры в nexus.
* [upload-file.sh](00-ansible/roles/prepare-hosts/files/upload-files.sh) - загружает файлы в хранилище files nexus.

Поскольку для ssl сертификата nexux-proxy (nginx) мы использовали свой собственный CA. Что бы всё работало, нам 
потребуется добавить этот сертификат в список доверенный СА сертифкатов на всех, серверах, куда мы будем устанавливать 
kubernetes. Для этого воспользуемся простейшим плейбуком [prepare-cluster.yaml](00-ansible/prepare-cluster.yaml).

    ansible-playbook prepare-cluster.yaml

Прежде чем мы их загрузим, залогинимся в хранилище контейнеров. 

    docker login --username=docker-user --password=password starter.kryukov.local

tags.sh

```bash
#!/usr/bin/env bash
DOCKER_HUB="starter.kryukov.local"
cd
echo "Load images from files"
for I in $(ls k8s-images); do
    echo "  Load k8s-images/$I"
    docker load < k8s-images/$I
done

echo "Start tags & push images"
for IMAGE in $(docker images | sed -e '1d' | awk '{ print $1 ":" $2 }' | grep -v 'sonatype/nexus3' | grep -v kubespray | grep -v 'nginx:1.21.6-alpine')
do
    echo "==========================================================="
    if $(echo $IMAGE | grep -E '^k8s.gcr.io|^quay.io' > /dev/null); then
        TEMP=$(echo "${IMAGE##k8s.gcr.io\/}")
        NEW_IMAGE="$DOCKER_HUB/$(echo ${TEMP##quay.io\/})"
    else
        NEW_IMAGE="$DOCKER_HUB/library/$IMAGE"
    fi
    echo "$IMAGE --> $NEW_IMAGE"
    docker tag $IMAGE $NEW_IMAGE
    docker push $NEW_IMAGE
done
```

upload-file.sh
```bash
#!/usr/bin/env bash
NEXUS=nexus.kryukov.local
SRC_DIR=/root/docker-images
KUBE_VERSION=v1.23.5
cd

for FILE in $( ls $SRC_DIR )
do
    if [ -f $SRC_DIR/$FILE ]; then
        echo "upload $SRC_DIR/$FILE"
        curl -v -u docker-user:password --upload-file $SRC_DIR/$FILE http://$NEXUS/repository/files/k8s/$KUBE_VERSION/$FILE
    fi
done
```

## 3. Настройка kubespray на использование хранилища.

Для настройки kubespray мы изменим два файла:
* inventory/cluster-offline/group_vars/all/offline.yml
* inventory/cluster-offline/group_vars/all/containerd.yml

Ниже приведены только значащие строки из итогового offline.yml
```yaml
registry_host: "starter.kryukov.local"
files_repo: "http://docker-user:password@nexus.kryukov.local/repository/files/k8s"
yum_repo: "http://nexus.kryukov.local/rpm"
kube_image_repo: "{{ registry_host }}"
gcr_image_repo: "{{ registry_host }}"
github_image_repo: "{{ registry_host }}"
docker_image_repo: "{{ registry_host }}"
quay_image_repo: "{{ registry_host }}"
kubeadm_download_url: "{{ files_repo }}/{{ kube_version }}/kubeadm-{{ kube_version }}-amd64"
kubectl_download_url: "{{ files_repo }}/{{ kube_version }}/kubectl-{{ kube_version }}-amd64"
kubelet_download_url: "{{ files_repo }}/{{ kube_version }}/kubelet-{{ kube_version }}-amd64"
cni_download_url: "{{ files_repo }}/{{ kube_version }}/cni-plugins-linux-{{ image_arch }}-{{ cni_version }}.tgz"
crictl_download_url: "{{ files_repo }}/{{ kube_version }}/crictl-{{ crictl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
etcd_download_url: "{{ files_repo }}/{{ kube_version }}/etcd-{{ etcd_version }}-linux-amd64.tar.gz"
calicoctl_download_url: "{{ files_repo }}/{{ kube_version }}/calicoctl"
runc_download_url: "{{ files_repo }}/{{ kube_version }}/runc"
containerd_download_url: "{{ files_repo }}/{{ kube_version }}/containerd-{{ containerd_version }}-linux-{{ image_arch }}.tar.gz"
nerdctl_download_url: "{{ files_repo }}/{{ kube_version }}/nerdctl-{{ nerdctl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
```

Файл containerd.yml

```yaml
containerd_registries:
   "starter.kryukov.local": "https://starter.kryukov.local"
containerd_registry_auth:
   - registry: "starter.kryukov.local"
     username: docker-user
     password: password
```

Предполагается, что данных из файла containerd.yml достаточно, что бы приложения могли логиниться в хаб. Но...
нет. Последняя версия nerdctl (используется в kybespray для работы с контейнерами) 
[перестала работать](https://github.com/containerd/nerdctl/blob/master/docs/faq.md#nerdctl-ignores-pluginsiocontainerdgrpcv1cri-config) с 
[plugins."io.containerd.grpc.v1.cri"] config.

Поэтому запускаем установку кластера первый раз. Получаем ошибку. Затем "вручную" логинимся в хабе на каждой ноде 
при помощи плейбука nerd-login.yaml. И повторно запускаем kubespray.

## Ссылка на видео.

Telegramm: https://t.me/arturkryukov/26

VK: https://vk.com/video7111833_456239187

[<img src="https://img.youtube.com/vi/JE-EkrddIJ8/maxresdefault.jpg" width="50%">](https://youtu.be/JE-EkrddIJ8)
