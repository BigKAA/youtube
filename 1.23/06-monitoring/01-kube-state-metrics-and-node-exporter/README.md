# kube-state-metrics

Для установки используется [helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics).

## Установка

### Helm chart

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install kube-state-metrics prometheus-community/kube-state-metrics
    helm install node-exporter prometheus-community/prometheus-node-exporter

### ArgoCD

ArgoCD использует чарты из директории [charts](../../charts).

Приложение для ArgoCD - [argoapp.yaml](argoapp.yaml)