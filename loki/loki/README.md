# Loki

За основу берем официальный [helm chart](https://github.com/grafana/helm-charts/tree/main/charts/loki-distributed)


    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update

    helm template loki grafana/loki-distributed -f values.yaml --namespace loki | \
    sed '/^#/d' | \
    sed '/helm.sh\/chart/d' | \
    sed '/chart: loki/d' | \
    sed '/heritage: Helm/d' | \
    sed '/managed-by: Helm/d' > manifests/loki.yaml

