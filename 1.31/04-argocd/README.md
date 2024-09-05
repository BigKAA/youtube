# ArgoCD

[Документация](https://argo-cd.readthedocs.io/en/stable/).

Добавляем Helm chart:

```shell
helm repo add https://argoproj.github.io/argo-helm
helm repo update
```

```shell
helm install argocd argocd/argo-cd -f argo-values.yaml -n argocd --create-namespace --version 7.4.7
```

Как генерировать пароль для админа написано в комментариях к secret в файле `argo-values.yaml`.
