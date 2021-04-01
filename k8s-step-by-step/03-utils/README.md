# Утилиты (продолжение)

## Ingress controller

* Ставим два контроллера.
* Сервис типа NodePort.
  * nodePort: 31080
  * nodePort: 31443

Поскольку кластер маленький, не привязываемся к конкретным нодам. Но
при этом запрещаем запуск двух подов контроллера на одной ноде.

## Helm

https://helm.sh/

https://github.com/helm/helm/releases    
    
    wget https://get.helm.sh/helm-v3.5.3-linux-amd64.tar.gz
    tar -xzf helm-v3.5.3-linux-amd64.tar.gz
    mv helm-v3.5.3 /usr/local/bin
    ln -s /usr/local/bin/helm-v3.5.3 /usr/local/bin/helm

    helm repo add stable https://charts.helm.sh/stable
    helm search repo stable

## Сертификаты для ingress

В первую очередь создаем сикрет с ключём и сертификатом CA. Что бы не
мучиться берем их из текущей версии кубера.

    kubectl -n monitoring create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt \
    --key=/etc/kubernetes/ssl/ca.key

Изучаем файл 00-certs.yaml. В файле используются CRD, добавленыый при
установке certmanager.

## Netdata

https://learn.netdata.cloud/docs

    helm repo add netdata https://netdata.github.io/helmchart/

https://github.com/netdata/helmchart/tree/master/charts/netdata

    helm install --set image.pullPolicy=IfNotPresent --set ingress.enabled=true --set ingress.hosts={mon.kryukov.local} \
    --set ingress.annotations={kubernetes.io/ingress.class: system-ingress} \
    --set parent.database.storageclass=managed-nfs-storage --set parent.alarms.storageclass=managed-nfs-storage \
    --set image.tag=1.30.0 --set sd.image.pullPolicy=IfNotPresent  --namespace monitoring \
    --set child.resources.limits.cpu=1 --set child.resources.limits.memory=1024Mi \
    netdata netdata/netdata \
    --debug --dry-run