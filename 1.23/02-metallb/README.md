# Metallb

[https://metallb.universe.tf/](https://metallb.universe.tf/)

По умолчанию, kubeproxy запущен без strictARP: true. Исправим это, отредактировав
соответствующий configmap:

    kubectl edit configmap -n kube-system kube-proxy

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

Установим metallb:

    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml

Применяем базовую конфигурацию layer2.

    kubectl apply -f mlb.yaml
