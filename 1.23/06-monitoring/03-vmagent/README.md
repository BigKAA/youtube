# vmagent

[Helm charts victoriametrics](https://github.com/VictoriaMetrics/helm-charts)

Для установки использую чарт [victoria-metrics-agent](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-agent)

## Установка

### Helm

Для установки использую свой файл [values](values.yaml)

    helm repo add vm https://victoriametrics.github.io/helm-charts/
    helm repo update
    helm install vm -n monitoring vm/victoria-metrics-single -f values.yaml

### ArgoCD

Файл приложения [argoapp.yaml](argoapp.yaml).

Использую [свой чарт](../../charts/03-vmagent). По сути это обертка над стандартным чартом, но так
удобно выносить values в отдельный файл, а не писать его в файл argoapp.