# Rancher 2.6

**Важно!** Rancher конфликтует с ArgoCD. Поэтому выберите что-то одно или не смешивайте приложения,
управляемые rancher и argocd.

**Важно!** Rancher создаёт много служебных namespaces. Если будете сносить rancher эти namespaces придётся удалять
вручную.

**Важно!** Перед установкой rancher установите certmanager и ingress controller.

    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
    kubectl create namespace cattle-system

Helm chart версии 2.6.3 не совместим с kubernetes 1.23. _По состоянию на Январь 2022_. Но это можно обойти :)

    helm pull rancher-stable/rancher --untar

В появившейся директории с чартом вносим изменения в файл Chart.yaml.

```yaml
kubeVersion: < 1.24.0-0
```

Устанавливаем из локального чарта.

    helm install rancher ./rancher \
    --namespace cattle-system \
    --set hostname=rancher.kryukov.local \
    --set bootstrapPassword=admin \
    --set replicas=1

**ИМХО** Rancher не торт. Смотрите в сторону ArgoCD.