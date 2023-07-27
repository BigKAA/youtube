# Gitlab runner

В WEB интерфейсе создай runner. Получите токен и подставьте eго значение в Secret.  

```shell
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: dev-gitlab-runner
  namespace: gitlab
type: Opaque
stringData:
  # Этот способ регистрации устаревший, с некоторыми проблемами. Поле всегда оставляем пустым.
  runner-registration-token: ""
  
  # тут подставляем полученный в WEB интерфейсе токен
  runner-token: "glrt-haAD9no41YLEnJfNEdJu"
  
  # S3 cache parameters
  accesskey: "admin"
  secretkey: "password"
EOF
```

```shell
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm search repo gitlab/gitlab
```

```shell
helm install dev-gitlab-runner gitlab/gitlab-runner -f my-values.yaml -n gitlab
```

```shell
helm uninstall dev-gitlab-runner -n gitlab
```

## Тестовый проект

За основу берем тестовые приложения из цикла видео про [tracing](../../tracing).

В GitLab создадим группу dev и проект base-application.

Переходим в директорию, где будут находиться ваши проекты.

```shell
git clone http://gitlab.kryukov.local/dev/base-application.git
```

Скопируем в директорию проекта файлы из директории 
[tracing/for_developersbase_application](../../tracing/for_developers/base_application).

Cоздадим файл `.gitlab-ci.yml`

```yaml
stages:
  - build
  - step1
  - step2

variables:
  REGISTRY: "https://index.docker.io/v1/"
  VERSION:
    value: ""
    description: "Введите tag (версию) контейнера. Пример: v0.0.1"

.build: &build_def
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:v1.11.0-debug
    entrypoint: [""]
  before_script:
    - |
      if [ -z $VERSION ]; then
        echo "Please select a container version"
        exit 1 
      fi
    - echo ${PROJECT_DIR}
    - echo ${CONTAINER_NAME}
    - echo "{\"auths\":{\"${REGISTRY}\":{\"auth\":\"$(printf "%s:%s" "${REGISTRY_USER}" "${REGISTRY_PASSWORD}" | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
  script:
    - echo "Build container..."
    - /kaniko/executor 
      --context $PROJECT_DIR 
      --dockerfile $PROJECT_DIR/Dockerfile 
      --destination ${CONTAINER_NAME}
  tags:
    - stage
  when: manual
  only:
    - web

application1: 
  <<: *build_def
  variables:
    CONTAINER_NAME: bigkaa/gitlab-application1:${VERSION}
    PROJECT_DIR: ${CI_PROJECT_DIR}/application1

application2: 
  <<: *build_def
  variables:
    CONTAINER_NAME: bigkaa/gitlab-application2:${VERSION}
    PROJECT_DIR: ${CI_PROJECT_DIR}/application2

step1:
  stage: step1 
  cache:
    key: test-cache
    paths:
      - some_path/
  script:
    - mkdir some_path
    - echo "Hello from step1" > some_path/hello.txt 
  tags:
    - stage
  when: manual
  only:
    - web

step2:
  stage: step2 
  cache:
    key: test-cache
    paths:
      - some_path/
  script:
    - cat some_path/hello.txt
  tags:
    - stage
  when: manual
  only:
    - web
```

```shell
git status
```

```shell
git commit -m "initial commit"
git push
```

[Про использование кеш](https://docs.gitlab.com/ee/ci/caching/#cache-python-dependencies).

## Видео

* [VK](https://vk.com/video7111833_456239247)
* [Telegram](https://t.me/arturkryukov/282)
* [Rutube]() 
* [Zen](https://dzen.ru/video/watch/64c2051a2fe792267219e1db)
* [Youtube](https://youtu.be/LjIzdnJGgVA)