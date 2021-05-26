# Keycloak

https://www.keycloak.org/

helmchart https://github.com/codecentric/helm-charts/tree/master/charts/keycloak

    helm repo add codecentric https://codecentric.github.io/helm-charts
    helm template keycloak codecentric/keycloak -n keycloak -f values.yaml > manifests/01-keykloak.yaml

