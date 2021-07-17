# Loki

За основу берем официальный [helm chart](https://github.com/grafana/helm-charts/tree/main/charts/loki)

    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update

    helm template loki grafana/loki -f values.yaml --namespace loki | \
    sed '/^#/d' | \
    sed '/helm.sh\/chart/d' | \
    sed '/managed-by: Helm/d' > manifests/loki.yaml
