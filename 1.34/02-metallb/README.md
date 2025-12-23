# Metallb

Контроллер для поддержки сервисов типа LoadBalancer.

[https://metallb.universe.tf/](https://metallb.universe.tf/)

**Важно!** Если `kubeproxy` запущен без параметра `strictARP: true`. Исправим это, отредактировав
соответствующий configmap:

```shell
kubectl edit configmap -n kube-system kube-proxy
```

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

Установим последнюю (на момент написания этого руководства) версию metallb:

```shell
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

Подождем пока применятся все CRD и запустятся все поды:

```shell
kubectl wait -n metallb-system --for=condition=Ready pods --selector "app=metallb"
```

Применяем конфигурацию:

```shell
kubectl -n metallb-system apply -f mlb.yaml
```
