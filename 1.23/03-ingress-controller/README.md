# Ingress controller

Ставим при помощи [helm chart](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx)

    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm search repo | grep ingress

Проверяем генерацию манифестов.

    helm template ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml --namespace ingress-nginx > in.yaml

Устанавливаем контроллер.

    helm install ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml --namespace ingress-nginx --create-namespace
    helm list --namespace ingress-nginx
