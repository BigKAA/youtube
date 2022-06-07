# Утилиты

## Docker образ для работы с kubernetes

Образ содержит helm и kubectl

    docker build -t kubectl_helm:1.22.3 .

## Модифицированный busybox

Добавлены утилиты gettext.

В основном из-за программы [envsubst](https://www.gnu.org/software/gettext/manual/gettext.html#envsubst-Invocation)

    docker build -t m_busybox:3.14.2 .

## Fastnginx Helm Chart

Быстрый деплой nginx в кластер kubernetes.