# Базовые приложения

Устанавливаем базовые вещи, которые понадобятся в будущем.

* PriorityClass
* nfs-subdir-external-provisioner
* cert-manager

```shell
kubectl create -f 00-priorityclass.yaml
kubectl -n kube-system create -f 01-nfs.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
```

## Helm

```shell
wget https://get.helm.sh/helm-v3.10.0-linux-amd64.tar.gz
tar -zxvf helm-v3.10.0-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/local/bin/helm
helm version
helm list
rm -rf helm-v3.10.0-linux-amd64.tar.gz linux-amd64
```
