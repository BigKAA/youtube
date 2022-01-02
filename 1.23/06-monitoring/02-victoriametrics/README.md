# Victoriametrics

[Helm charts victoriametrics](https://github.com/VictoriaMetrics/helm-charts)

Ставлю [victoria-metrics-single](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-single)

## Установка

### Helm

Для установки использую свой файл [values](values.yaml)

    helm repo add vm https://victoriametrics.github.io/helm-charts/
    helm repo update
    helm install vm -n monitoring vm/victoria-metrics-single -f values.yaml

### ArgoCD

Файл приложения [argoapp.yaml](argoapp.yaml).

Использую [свой чарт](../../charts/02-victoriametrics). По сути это обертка над стандартным чартом, но так 
удобно выносить values в отдельный файл, а не писать его в файл argoapp.

```yaml
    helm:
      valueFiles:
        - my-values.yaml
```
