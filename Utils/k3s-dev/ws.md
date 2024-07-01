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
