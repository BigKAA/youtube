# Утилиты (продолжение)

## Ingress controller

* Ставим два пода.
* Сервис типа NodePort.
  * nodePort: 31080
  * nodePort: 31443

Поскольку кластер маленький, не привязываемся к конкретным нодам. Но
при этом запрещаем запуск двух подов контроллера на одной ноде.

**Update** *С момента записи видео прошло много времени. В файле манифеста подставьте актуальный `image` из
[GitHub](https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.9.4).*

**Best way** -> *Или воспользуйтесь установкой контроллера при помощи helm. Как это описано в [1.26](../../1.26/03-ingress-controller)* 

## Helm

https://helm.sh/

https://github.com/helm/helm/releases    
    
    curl -o helm-v3.5.3-linux-amd64.tar.gz https://get.helm.sh/helm-v3.5.3-linux-amd64.tar.gz
    tar -xzf helm-v3.5.3-linux-amd64.tar.gz
    mv linux-amd64/helm /usr/local/bin/helm-v3.5.3
    ln -s /usr/local/bin/helm-v3.5.3 /usr/local/bin/helm
    rm -rf linux-amd64

    helm version
    helm repo add stable https://charts.helm.sh/stable
    helm search repo stable

Почти все чарты в состоянии DEPRECATED :)

## Сертификаты для ingress

В первую очередь создаем сикрет с ключём и сертификатом CA. Что бы не
мучиться берем их из текущей версии кубера.

    kubectl -n monitoring create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt \
    --key=/etc/kubernetes/ssl/ca.key

Изучаем файл 02-certs.yaml. В файле используются CRD, добавленные при
установке certmanager.

Применяем файл.

    kubectl -n monitoring get issuers
    kubectl -n monitoring get certificate

## Netdata

https://learn.netdata.cloud/docs

    helm repo add netdata https://netdata.github.io/helmchart/
    helm search repo netdata

https://github.com/netdata/helmchart/tree/master/charts/netdata

    helm install --set image.pullPolicy=IfNotPresent --set ingress.enabled=false \
    --set parent.database.storageclass=managed-nfs-storage --set parent.alarms.storageclass=managed-nfs-storage \
    --set image.tag=v1.30.0 --set sd.image.pullPolicy=IfNotPresent  \
    --set child.resources.limits.cpu=1 --set child.resources.limits.memory=1024Mi \
    --set child.resources.requests.cpu=0\.2 --set child.resources.requests.memory=128Mi \
    --set parent.resources.limits.cpu=1 --set parent.resources.limits.memory=1024Mi \
    --namespace monitoring netdata netdata/netdata \
    --debug --dry-run

    helm --namespace monitoring list

Применяем файл 03-netdata-ingress.yaml

## Видео

[<img src="https://img.youtube.com/vi/e3JTpfpMG3E/maxresdefault.jpg" width="50%">](https://www.youtube.com/watch?v=e3JTpfpMG3E)

