# Мониторинг

На всякий пожарный ставим экспортёры. Всё равно рано или поздно эти метрики потребуются. 

## kube-state-metrics

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-state-metrics prometheus-community/kube-state-metrics -n monitoring --create-namespace
```

## node-exporter

В kubernetes v1.25 удалили PodSecurityPolicy. Будем пользоваться [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/).

Учитывая, что node-exporter требует доступы к локальной файловой системе, сделаем для него отдельный namespace c привилегированным доступом.

```shell
kubectl apply -f 00-node-exporter-ns.yaml
```

На момент написания этой страницы, в чарте node-exporter используется PodSecurityPolicy. Поэтому при помощи
helm создадим манифест [02-ne.yaml](02-ne.yaml) , в котором удалим PodSecurityPolicy.

```shell
helm template node-exporter prometheus-community/prometheus-node-exporter -n node-exporter > 02-ne.yaml
```

```shell
kubectl apply -f 02-ne.yaml
```