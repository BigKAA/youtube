# Grafana

Графану устанавливаем как на этом видео.

[<img src="https://img.youtube.com/vi/trHNN-X_BUE/maxresdefault.jpg" width="50%">](https://youtu.be/trHNN-X_BUE&t=907s)

С небольшим изvенениями в ConfigMap

Установка в командной строке:

    kubectl create ns loki
    kubectl -n loki apply -f manifests/

Установка как приложение ArgoCD:

    kubectl -n loki apply -f argo-app/argo-app.yaml

## Видео

[<img src="https://img.youtube.com/vi/cAiBsaAO_IM/maxresdefault.jpg" width="50%">](https://youtu.be/cAiBsaAO_IM)
