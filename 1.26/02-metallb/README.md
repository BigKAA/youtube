# Metallb

[https://metallb.universe.tf/](https://metallb.universe.tf/)

Если kubeproxy запущен без strictARP: true. Исправим это, отредактировав
соответствующий configmap:

    kubectl edit configmap -n kube-system kube-proxy

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

Если вы используете ansible [00-ansible](../00-ansible/), эти параметры устанавливаются автоматически.

Установим metallb:

```shell
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
```

Применяем конфигурацию:

```shell
kubectl -n metallb-system apply -f mlb.yaml
```