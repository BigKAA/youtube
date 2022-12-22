# Spilo helm chart

Чарт построен на базе проекта [zalando/spilo](https://github.com/zalando/spilo)

## Пароли

Пароли административных пользователей хранятся в сикрете. Его можно создать заранее в namespace, в котором 
будет размещаться приложение. Или определить пароли в файле values: `secret.defaultPassword`. 

* postgresPassword
* replicationPassword
* superadminPassword

Пример сикрета:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: pg-secret
type: Opaque
stringData:
  postgresPassword: password
  replicationPassword: password
  superadminPassword: password
```

## Известные глюки.

После удаления чарта автоматически не удаляется сервис.

Из-за автоматических изменений в манифестах, которые делает patrony, непонятно как это
решение деплоить при помощи ArgoCD.