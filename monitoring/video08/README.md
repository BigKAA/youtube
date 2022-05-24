# Alertmanager

[Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) - обрабатывает алёрты, отправляемые 
клиентскими приложениями. Заботится о дедупликации, группировке и маршрутизации алёртов к получателям.

## Конфигурационный файл

### Секция global

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.mail.ru:465'
  smtp_require_tls: false
  smtp_auth_username: "$SMTP_USER"
  smtp_auth_password: "$SMTP_PASSWORD"
```

resolve_timeout — значение по умолчанию, используемое alertmanager, если алёрт не включает поле EndsAt, 
по истечении этого времени он может объявить алёрт разрешенным, если он не было обновлено. 
Не влияет на оповещения от Prometheus, так как они всегда содержат EndsAt.

### Templates

[Примеры шаблонов](https://github.com/prometheus/alertmanager/tree/main/template)

### Секция receivers

```yaml
receivers:
- name: mail
  email_configs:
  - to: 'artur@kryukov.moscow'
    from: 'artur@kryukov.moscow'
    send_resolved: true
- name: telegram
  telegram_configs:
  - send_resolved: true
    bot_token: $BOT_TOKEN
    chat_id: $CHAT_ID
    api_url: "https://api.telegram.org"
    parse_mode: HTML
```

### Секция route

```yaml
route:
  group_interval: 5m # время отправки повторного сообщения для группы.
  group_wait: 10s # время ожидания перед отправкой уведомления для группы.
  repeat_interval: 3h # время до отправки повторного сообщения.
  group_by: ['alertname', 'priority'] # По каким меткам группировать.
  receiver: mail

  routes:
  - matchers:
      - severity=~critical|warning
    receiver: mail
    continue: true
  - matchers:
      - severity=~critical|warning
    receiver: telegram
```

## Видео

[<img src="https://img.youtube.com/vi/ABRy8LBuzSs/maxresdefault.jpg" width="50%">](https://youtu.be/ABRy8LBuzSs)