# Ingress controller

Ставим при помощи [helm chart](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx).

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo | grep ingress
```

Проверяем генерацию манифестов.

```shell
helm template ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml -n ingress-nginx > in.yaml
```

Устанавливаем контроллер.

```shell
helm install ingress-nginx ingress-nginx/ingress-nginx -f my-values.yaml -n ingress-nginx --create-namespace
helm list -n ingress-nginx
```

Проверяем доступность сервиса типа LoadBalancer

```shell
kubectl -n ingress-nginx get svc
```

Контролируем, что mtallb выдал кластерный IP. Поле EXTERNAL-IP. 

Проверяем, что контроллер отвечает на запросы.

```shell
curl http://192.168.218.180
```

В ответ должны получить сообщение об ошибке 404.
