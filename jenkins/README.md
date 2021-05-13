# Jenkins

Деплой одного экземпляра Jenkins со встроенным модулем
kubernetes.

## Собираем образ.

    # docker build -t bigkaa/jenkins:v0.1 docker-jenkins
    # docker tag bigkaa/jenkins:v0.1 n.kryukov.local/bigkaa/jenkins:v0.1
    # docker push n.kryukov.local/bigkaa/jenkins:v0.1
    
    # docker build -t bigkaa/inbound-agent:v0.1 docker-inbound-agent
    # docker tag bigkaa/inbound-agent:v0.1 n.kryukov.local/bigkaa/inbound-agent:v0.1
    # docker push n.kryukov.local/bigkaa/inbound-agent:v0.1

## На каждой ноде кластера копируем сертификат CA kubernetes

    # mkdir -p /etc/docker/certs.d/n.kryukov.local
    # cp /etc/kubernetes/pki/ca.crt /etc/docker/certs.d/n.kryukov.local

## Добавляем namespace

    # kubectl apply 00-ns.yaml

## Создаем secret docker registry

    # docker login -u docker-user -p password n.kryukov.local
    # cp ~/.docker/config.json ~
    # kubectl -n jenkins create secret generic kryukov-local \
     --from-file=.dockerconfigjson=config.json \
     --type=kubernetes.io/dockerconfigjson

## Деплоим приложения

    # kubectl apply -f 01-rbac.yaml
    # kubectl apply -f 02-deployment.yaml

Смотрим логи jenkins, ищем первоначальный пароль админа.

После установки, удаляем внутренние executors и конфигурируем модуль kubernetes

## Видео

* https://youtu.be/FNTFVSavQY8
* https://youtu.be/q4FjUpnWDFY

