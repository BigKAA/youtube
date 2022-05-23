# Alertmanager

[Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) - обрабатывает алёрты, отправляемые 
клиентскими приложениями. Заботится о дедупликации, группировке и маршрутизации алёртов к получателям.

## Конфигурационный файл

### Секция global

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'aspmx.l.google.com:25'
  smtp_require_tls: false
```

resolve_timeout — значение по умолчанию, используемое alertmanager, если алёрт не включает поле EndsAt, 
по истечении этого времени он может объявить алёрт разрешенным, если он не было обновлено. 
Не влияет на оповещения от Prometheus, так как они всегда содержат EndsAt.

### Templates

[Примеры шаблонов](https://github.com/prometheus/alertmanager/tree/main/template)

### Секция receivers

```yaml
receivers:
- name: gmail
  email_configs:
  - to: 'artur@kryukov.biz'
    from: alert@kryukov.biz
    send_resolved: true
- name: 'telegramm'
  webhook_configs:
  - url: 'http://alertmanager-bot:8080'
    send_resolved: true
```

### Секция route

```yaml
route:
  group_by: ['alertname', 'severity', 'hostname', 'namespace', ] # По каким меткам группировать.
  group_wait: 10s # время ожидания перед отправкой уведомления для группы.
  group_interval: 5m # время отправки повторного сообщения для группы.
  repeat_interval: 3h # время до отправки повторного сообщения.
  receiver: default # имя receiver-a.
  routes:
  - match_re: 
      severity: ^(critical|warning)$
    receiver: telegramm
    continue: true
  - match_re:
      severity: ^critical$
    receiver: gmail
    continue: true
```

### Telegramm

Пока в RC release-0.24

https://github.com/prometheus/alertmanager/blob/release-0.24/docs/configuration.md#telegram_config

```yaml
receivers:
- name: 'telegramm'
  telegram_config:
  - api_url: 'https://api.telegramm.org'
    bot_token: TOKEN
    chat_id: 11111111
    message: '{{ telegramm.default.message }}'
    parse_mode: MarkdownV2
    send_resolved: true
```