# Keycloak

https://www.keycloak.org/

helmchart https://github.com/codecentric/helm-charts/tree/master/charts/keycloak

## Metallb

[https://metallb.universe.tf/](https://metallb.universe.tf/)

Убедится, что KubeProxy запущен с параметром: 

```yaml
ipvs:
  strictARP: true
```

```shell
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
```

Только при первой установке создаём сикрет:

```shell
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

Применяем базовую конфигурацию layer2.

```shell
kubectl apply -f metallb/00-mlb.yaml
```

Добавляем сервис для ingres-controller типа LoadBalancer

```shell
kubectl apply -f metallb/01-lb-ingress-controller-svc.yaml
```

## Установка keycloak

У нас установлен cert-manager. Добавляем ClusterIssuer (если он еще не установлен).

```shell
kubectl -n cert-manager create secret tls kube-ca-secret \
    --cert=/etc/kubernetes/ssl/ca.crt \
    --key=/etc/kubernetes/ssl/ca.key
```
```shell
kubectl -n keycloak apply -f 00-certs.yaml
```
   

Подготовка манифестов

```shell
helm repo add codecentric https://codecentric.github.io/helm-charts
helm template kk codecentric/keycloak -f values.yaml | \
    sed '/^#/d' | \
    sed '/helm.sh\/chart/d' | \
    sed '/managed-by: Helm/d' | \
    sed '/serviceName: kk-headless/d' | \
    sed '/podManagementPolicy/d' | \
    sed '/updateStrategy/d' | \
    sed '/type: RollingUpdate/d' | \
    sed '/serviceName/d' | \
    sed '/kind: StatefulSet/c\kind: Deployment' > manifests/02-keycloak.yaml
```

Установка. Можно руками:

```shell
kubectl -n keycloak apply -f manifests
```

Можно при помощи ArgoCD:
    
Пушим manifests/* в Git. Редактируем argo-app/{00-iam-project.yaml,01-keycloak-app.yaml}

```shell
kubectl  apply -f argo-app
```

## Настройка ArgoCD

https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/

## Ссылка на видео.

Metallb:

[<img src="https://img.youtube.com/vi/B8FdhbNDS3Q/maxresdefault.jpg" width="50%">](https://youtu.be/B8FdhbNDS3Q)

Keycloak:

[<img src="https://img.youtube.com/vi/XlBd1BLysQI/maxresdefault.jpg" width="50%">](https://youtu.be/XlBd1BLysQI)

Keycloak + ArgoCD:

[<img src="https://img.youtube.com/vi/kMPikjvdKXg/maxresdefault.jpg" width="50%">](https://youtu.be/kMPikjvdKXg)
