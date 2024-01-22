# Установка базовых компонентов

После первоначального развертывания кластера k3s добавим в него базовые приложения.

## Приоритеты

```shell
kubectl apply -f base-apps/00-priorityclass.yaml
```

## Cert manager

```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
```

## NFS StorageClass

```shell
kubectl -n kube-system apply -f base-apps/01-nfs.yaml
```

## Ingress Controller

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo | grep ingress
```

```shell
helm install ingress-nginx ingress-nginx/ingress-nginx -f base-apps/my-values.yaml -n ingress-nginx --create-namespace
```

## ArgoCD

```shell
helm repo add https://argoproj.github.io/argo-helm
helm repo update
```

```shell
helm install argocd argocd/argo-cd -f base-apps/argo-values.yaml -n argocd --create-namespace
```

Как генерировать пароль для админа написано в комментариях к secret в файле `argo-values.yaml`.