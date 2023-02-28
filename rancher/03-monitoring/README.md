# Настройка уведомлений

## Как в документации

### Alertmanager Configs

Заходим в Rancher обыкновенным пользователем.

`Alerting` -> `AlertmanagerConfigs` -> `Create`

* `Namespace` -> `test-app`
* `Name` -> `test-app`
* `Description` -> `Test app alerting`

Press `Create`

Добавим secret, содержащий пароль почтового пользователя

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mail-user
  namespace: test-app
type: Opaque
stringData:
  PASSWORD: 'ТУТ ПАРОЛЬ ПОЛЬЗОВАТЕЛЯ'
```

```shell
kubectl apply -f manifests/00-mail-user-password.yaml
```

`Receivers` -> `Add Receiver` -> `Email` -> `Add Email`

* `name` -> `artur-mail`
* `Target` -> `artur@kryukov.moscow`
* Check `Enable send resolved alerts`
* `SMTP` - `Sender` -> `artur@kryukov.moscow`
* `SMTP` - `Host` -> `smtp.mail.ru:465`
* `SMTP` - `Auth Username` -> `artur@kryukov.moscow`
* `SMTP` - `Secret with Auth Password` -> `mail-user`
* `SMTP` - `Key` -> `PASSWORD`

Press `Create`

Route

* `Receiver` -> `artur-mail`
* `Grouping` -> `alertname`, `group`
* `Matchers`
  * `Name` -> `severity`
  * `Value` -> `warning|critical`
  * `Match Type` -> `Match Regexp`

Press `Save`

### Prometheus rules

`Monitoring` -> `Advanced` -> `PrometheusRules` -> `Create`

* `Namespace` -> `test-app`
* `Name` -> `deployments`
* `Description` -> `Deployments rules`
* `Rule Group 1`
  * `Group Name` -> `Deployments`
  * `Override Group Interval` -> `15`
  * Press `Add Alert`
    * `AlertName` -> `ZeroDeploymentPods`
    * `PromQL Expression` -> `kube_deployment_status_replicas_available == 0`
    * Check `Severity`
    * `Severity Label Value` -> `warning`
    * `Key` -> `test`
    * Check `Summary`
    * `Summary Annotation Value` -> `Количество подов равно 0!`
    * Check `Message`
    * `Message Annotation Value` -> `Количество подов деплоймента {{ $labels.deployment }} равно 0!`
    * Check `Description`
    * `Description Annotation Value` -> `Количество подов деплоймента {{ $labels.deployment }} в namespace {{ $labels.namespace }} равно нулю!`

Press `Create`

```shell
kubectl -n test-app get deployments
kubectl -n test-app scale --replicas=0 deployment/test-app
```

Наслаждаемся тем, что оно нек работает. Удаляем созданный `AlertmanagerConfigs`.

## Как на самом деле.

Продолжение смотрите в видео.


