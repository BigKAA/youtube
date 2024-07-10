# Вспомогательные контейнеры

## Gitlab

В gitlab создаём группу `dev`.

В группе `dev` добавляем переменные:

- DEV_REGISTRY - `registry.kryukov.local`
- DEV_REGISTRY_USER - `admin`
- DEV_REGISTRY_PASSWORD - `password`
- DEV_CA - добавляем (как файл) сертификат нашего кастомного CA. *ca.crt находится в namespace `cert-manager`, secret `dev-ca`.*

В группе `dev` создаём группу `containers`.

## Контейнер kubeutils

Содержит утилиты: kubect, helm, regclient и kubeconform. Будет применяться при сборках приложений.

Контейнер можно собрать как при помощи docker там и непосредственно в gitlab.

### Сборка контейнера

В Gitlab в группе `containers` создаем проект `kubeutils`.

В проект добавляем файлы: `Dockerfile` и `.gitlab-ci.yml`. Файлы находятся [тут](ws/kubeutils).

## Рабочий контейнер

Если на текущей машине есть установленный docker то собираем при помощи docker.

Если docker отсутствует - не беда. У нас есть установленный gitlab и gitlab-runner

### Docker

```shell
docker login registry.kryukov.local
```

```shell
docker build -t registry.kryukov.local/library/ubuntu_ssh:24.04 .
```

```shell
docker push registry.kryukov.local/library/ubuntu_ssh:24.04
```

### Сборка контейнера в Gitlab

В gitlab в группе `dev` создаём проект `devcontainer_ubuntu`.

В проекте `devcontainer_ubuntu` добавляем переменную:

- CONTAINER_NAME - `library/ubuntu_ssh`

Добавляем в проект файлы из директории [devcontainer](ws/devcontainer).

## Чарт devcontainer

### Подготовка домашней директории

На машине, где работает k3s:

```shell
groupadd -g 1001 artur
useradd -u 1001 -g 1001 artur
passwd artur
```

На клиенте:

```shell
ssh-keygen -t ed25519
```

### Проект в Gitlab

В Gitlab в группе `dev` создаем группу `charts`. В ней создаём проект `devcontainer`

В Harbor создаём публичный проект `charts`.

```shell
git clone https://gitlab.kryukov.local/dev/charts/devcontainer.git
```

Копируем в проект директорию [devcontainer](charts/devcontainer) со всем содержимым.

Добавляем в файл `values.yaml` в массив `user.pubKey` элемент массива - публичный ssh ключ. Строку, так как она
записана в файле публичного ключа. Если вы используете несколько ssh ключей, в массив можно добавить несколько
публичных ключей.

Так же в `values.yaml` добавляем сертификат CA.

Добавляем в корень проекта файл [.gitlab-ci.yml](charts/devcontainer/.gitlab-ci.yml).

Пушим все обратно в git и запускам сборку чарта.

## Запуск контейнера

В ручную из локальных исходников:

```shell
helm install artur charts/devcontainer
```

В ручную, из репозитория:

```shell
helm install artur oci://registry.kryukov.local/charts/devcontainer --version 0.1.0
```

Или чарт k3s:

```shell
kubectl apply -f charts/devcontainer.yaml
```

ArgoCD:

```shell
kubectl apply -f argocd-apps/devcontainer.yaml
```

## Подключение к контейнеру

```shell
ssh artur@192.168.218.189 -p 31022
```
