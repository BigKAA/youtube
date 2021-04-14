# Утилиты и начальные действия

## Namespaces

00-namespace.yaml - создание необходимых для дальнейшей работы namespaces.

## Priority classes

01-priority-class.yaml - Приоритеты.

## Reloader

02-reloader.yaml - [Reloader](https://github.com/stakater/Reloader) - утилита для перезагрузки сервиса после изменения
comfigMap. [Образ](https://hub.docker.com/r/stakater/reloader/tags?page=1&ordering=last_updated) на DockerHub.

На что обратить внимание:
* Переменная среды окружения KUBERNETES_NAMESPACE. Если не определена, работает со всеми namespace кластера.
* Аргумент командной строки --namespaces-to-ignore - можно перечислить через запятую имена namespace, которые
программа будет игнорировать.

## Metrics server


[Metrics Server](https://github.com/kubernetes-sigs/metrics-server) - собирает метрики по использованию CPU и RAM.
Добавляет metrics API, используемый в инструментах горизонтального масштабирования подов. 

03-metrics-server.yaml

## Cert-manager

[cert-manager](https://cert-manager.io/docs/installation/kubernetes/) - утилита
для управления сертификатами.

    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
    kubectl get pods --namespace cert-manager

Namespace cert-manager создаётся автоматически.

## Persistent Volumes

https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner

Определение классов, постоянных хранилищ и всё что с этим связано.

Необходимо отредактировать деплоймент в части указания
правильных параметров nfs сервера.

## Видео

[<img src="https://img.youtube.com/vi/dHQXtsKUUzo/maxresdefault.jpg" width="50%">](https://www.youtube.com/watch?v=dHQXtsKUUzo)