# Отчеты

[Отчеты Kyverno](https://kyverno.io/docs/policy-reports/) позволяют увидеть результаты работы политик Kyverno и проводить их аудит.

Отчеты сохраняются в `kind` `PolicyReport` и `ClusterPolicyReport`. PolicyReport - это custom resource, который добавляется в кластер при помощи CRD. PolicyReport создаются автоматически и содержат информацию о применении Kyverno ClusterPolicy или Policy.

Отчеты создаются для правил `validate`, `mutate`, `generate` и `verifyImages` для каждого ресурса, к которому применяются политики Kyverno.

При удалении ресурсов их запись будет удалена из отчета. Таким образом, отчеты всегда отражают текущее состояние кластера и не содержат исторической информации.

Kyverno использует стандартный и открытый формат, опубликованный [Kubernetes Policy working group](https://github.com/kubernetes-sigs/wg-policy-prototypes/tree/master/policy-report), которая предлагает общий формат отчета о политике для всех инструментов Kubernetes.

Посмотреть список отчетов в определенном namespace:

```shell
kubectl -n user1 get policyreport
```

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  labels:
    app.kubernetes.io/managed-by: kyverno
  name: a95df676-2a3f-4dbc-ad83-b4215b9ac923
  namespace: user1
  ownerReferences:
  - apiVersion: v1
    kind: Pod
    name: test-secret-789f957778-4s4d9
    uid: a95df676-2a3f-4dbc-ad83-b4215b9ac923
  resourceVersion: "354124"
  uid: bc8b609c-77ec-4677-9944-3f1b99b0fdba
results:
```

`ownerReferences` содержит информацию о ресурсе, к которому применяются политики Kyverno.

В разделе `results` показаны результаты работы политик Kyverno для определенного ресурса.

```yaml
results:
  - category: Pod Security Standards (Restricted)
    message: validation rule 'restricted-volumes' passed.
    policy: disable-host-path-volumes
    result: pass
    rule: restricted-volumes
    scored: true
    severity: medium
    source: kyverno
    timestamp:
      nanos: 0
      seconds: 1735111909
```

`results` - содержит массив результатов работы политик Kyverno.

`scope` показывает объект, к которому применяются политики Kyverno.

```yaml
  scope:
    apiVersion: v1
    kind: Pod
    name: test-secret-789f957778-4s4d9
    namespace: user1
    uid: a95df676-2a3f-4dbc-ad83-b4215b9ac923
```

`result` содержит результат работы политики Kyverno.

- `pass` - Ресурс был применим к правилу, и шаблон прошел оценку.
- `scip` - Предварительные условия в правиле не были выполнены (если применимо), или существует исключение PolicyException, и поэтому дальнейшая обработка не выполнялась.
- `fail` - Ресурсу не удалось выполнить оценку шаблона.
- `warn` - Если в политике в аннотации `policies.kyverno.io/scored` было установлено значение `false`. вместо значения `fail` будет выдаваться `warn`.
- `error` - Ошибка при обработке политики.

## Background Scans

[Background Scans](https://kyverno.io/docs/policy-reports/background/).

При определении политик Kyverno по умолчанию включен режим background scan: `spec.background: true`.

Важно понимать, что background scan не влияет на уже существующие ресурсы в кластере. Для существующих ресурсов он не применяет политику Kyverno, а только генерирует отчеты.

## Policy Reporter

Работать с отчетами в командной строке крайне не удобно. Поэтому проект Kyverno предоставляет удобную командную строку для просмотра отчетов: [Policy Reporter](https://kyverno.github.io/policy-reporter/).

Для установки приложения будем использовать helm chart и ArgoCD.

```shell
kubectl apply -f manifests/03-kyverno-policy-reporter.yaml
```
