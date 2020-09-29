# Jenkins

Деплой одного экземпляря Jenkins со встроенным модулем
kubernetes.

Собираем образ.

    # docker build -t bigkaa/jenkins:v0.1 docker-jenkins
    # docker tag bigkaa/jenkins:v0.1 n.kryukov.local/bigkaa/jenkins:v0.1
    # docker push n.kryukov.local/bigkaa/jenkins:v0.1
    
    # docker build -t bigkaa/inbound-agent:v0.1 docker-inbound-agent
    # docker tag bigkaa/inbound-agent:v0.1 n.kryukov.local/bigkaa/inbound-agent:v0.1
    # docker push n.kryukov.local/bigkaa/inbound-agent:v0.1

Создаем secret docker registry

    # docker login -u docker-user -p password n.kryukov.local
    # kubectl -n jenkins create secret generic kryukov-local \
     --from-file=.dockerconfigjson=~/.docker/config.json \
     --type=kubernetes.io/dockerconfigjson

На каждой ноде кластера копируем сертификат CA kubernetes

    # mkdir -p /etc/docker/certs.d/n.kryukov.local
    # cp /etc/kubernetes/pki/ca.crt /etc/docker/certs.d/n.kryukov.local

