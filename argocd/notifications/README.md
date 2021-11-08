# Notification

https://argocd-notifications.readthedocs.io/en/stable/)

## Telegram chat
    
В телеграмме ищем бот BotFather.

    /newbot

Создаём своего бота. Получаем token. Сохраняем его в secret.

Создаём группу. Добавляем в нее бота.

От своего пользователя пишем в группу тестовое сообщение.

Запрашиваем информацию по боту.

    curl https://api.telegram.org/botТУТ_ТОКЕН/getUpdates

Ищем что то типа:

    "chat":{"id":-1009999999999,

Это ID чата, который в дальнейшем подставим в ConfigMap

## Конфигурация notification.

Сначала создаём secret в котором поместим токен.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
type: Opaque
stringData:
  telegram-token: "тут пишем токен"
```
    
    kubectl -n argocd apply -f secret.yaml

Деплоим приложение notification.

Или в командной строке:

    kubectl -n argocd apply -f 00-rbac.yaml -f 01-configs.yaml -f 02-deployment.yaml

или в ArgoCD 00-notification.yaml
