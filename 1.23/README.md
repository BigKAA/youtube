# kubernetes 1.23

В новой версии кубера изменилось большое количество API, поэтому сделал для него отдельную ветку.

Кластер кубера установлен при помощи kubeadm. В 
этот раз использую сетевой драйвер [Cilium](https://docs.cilium.io/en/stable/).

```
kubectl get nodes
NAME                     STATUS   ROLES                  AGE   VERSION
control1.kryukov.local   Ready    control-plane,master   18h   v1.23.1
db1.kryukov.local        Ready    <none>                 18h   v1.23.1
worker1.kryukov.local    Ready    <none>                 18h   v1.23.1
worker2.kryukov.local    Ready    <none>                 18h   v1.23.1
worker3.kryukov.local    Ready    <none>                 18h   v1.23.1
```

_**Внимание!** У меня поднят DNS сервер, поддерживающий домен kryukov.local. Учтите это, когда будете читать данную ветку._

_Эта ветка документации имеет справочный характер, видео по ней не будет._

1. [Базовые вещи.](01-base-app)
2. [Metallb](02-metallb) для сервисов типа LoadBalancer.
3. [Ingress controller](03-ingress-controller).
4. [ArgoCD](04-argocd).

После установки ArgoCD всё остальное ПО буду устанавливать при помощи ArgoCD.

5. [PostgreSQL](05-postgresql).
6. [Мониторинг](06-monitoring).