# Keycloak

https://www.keycloak.org/

helmchart https://github.com/codecentric/helm-charts/tree/master/charts/keycloak

    helm repo add codecentric https://codecentric.github.io/helm-charts
    helm template keycloak codecentric/keycloak -f values.yaml > manifests/02-keykloak.yaml
    kubectl -n keycloak apply -f manifests/02-keykloak.yaml
    kubectl -n keycloak apply -f manifests/03-ingress.yaml
