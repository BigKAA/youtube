# Update from 2.0 to 2.1

Скачиваем файл с манифестами.

    curl -o install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/latest/manifests/install.yaml
    
Мы должны сохранить предыдущие конфигурационные параметры, поэтому из файла удаляем:

* Secret argocd-secret
* ConfigMap argocd-rbac-cm и argocd-cm

Иначе при применении обновления, старые конфиги обнулятся.

Добавляем параметры в ConfigMap argocd-cmd-params-cm: 

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cmd-params-cm
data:
  ## Server properties
  # Run server without TLS
  server.insecure: "true"
  # Directory path that contains additional static assets
  server.staticassets: "/shared/app"
  server.log.format: "json"
  server.log.level: "debug"
```

Параметры в этом ConfigMap работают только при запуске приложения.

Применяем манифесты:

    kubectl -n argocd apply -f install.yaml

В ConfigMap argocd-cm исправляем url на https. Если вы используете keycloak, в keycloak в приложении argo 
соответственно изменяем все на https.

## Ссылка на видео.

[<img src="https://img.youtube.com/vi/TQjLq6wac3Y/maxresdefault.jpg" width="50%">](https://youtu.be/TQjLq6wac3Y)
