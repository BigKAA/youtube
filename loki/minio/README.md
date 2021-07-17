# Minio

Готовим установку minio для loki.

Основано на [Bitnami Object Storage Helm Chart based on MinIO](https://github.com/bitnami/charts/tree/master/bitnami/minio/#installing-the-chart)

Необходимо пометить две worker node при помощи label.

    kubectl label nodes worker1.kryukov.local minio=yes
    kubectl label nodes worker2.kryukov.local minio=yes

    helm repo add bitnami https://charts.bitnami.com/bitnami

    helm template mi bitnami/minio -f values.yaml --namespace loki | \
    sed '/^#/d' | \
    sed '/helm.sh\/chart/d' | \
    sed '/managed-by: Helm/d' > minio-in.yaml

Удаляем все что нам не надо из файла и копируем его в manifests/01-minio.yaml

## Установка

Ставим или руками:

    kubectl create ns loki
    kubectl apply -f manifests/

Или при помощи ArgoCD:

    kubectl apply -f argo-app/

## WEB interface

Поскольку был установлен ingress, доступ к WEB интерфейсу:

http://minio.kryukov.local
