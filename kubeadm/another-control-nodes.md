# Добавление control nodes

**Важно понимать, что в кластере должно быть нечётное количество control нод.**

После создания первой ноды кластера, kubeadm выведет на стандартный вывод команды для добавления новых нод.
Если не прошло больше суток после создания первой control ноды, то эти команды можно использовать для добавления.
Если прошло больше суток (время жизни сгенерированного токена), то придётся почитать этот раздел до конца.

Посмотреть список токенов можно следующим образом: 

```shell
kubeadm token list
```

В столбце TTL будет показано, сколько времени осталось до окончания действия токена.

## Подготовительные шаги

_На самом деле всё, что будет показано ниже можно сделать за меньшее количество шагов. Но этот пример в дальнейшем
будет легко автоматизировать._

Сначала создадим новый токен (_join_token_).

```shell
kubeadm token create
```

Программа выдаст на стандартный вывод новый токен. Что-то типа: `8g5max.xfbtvkmud52htbmv`.

Так же нам потребуется хеш сертификата CA (_ca_cert_hash_):

```shell
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'
```

На стандартном выводе получим что-то типа: `41ead9594abbcfb6d8c85cbde18e91ecb39669f08b6ac4093ebfed43d7a1e588`.

На следующем шаге поместим сертификаты в secret `kubeadm-certs` в namespace `kube-system`.

```shell
kubeadm init phase upload-certs --upload-certs | tail -1
```

В последней строке получим ключ сертификата (_certificate_key_). Что-то 
вроде: `3f47da5379374fe688e92ebc93d59a58e8b3b130aca807bc9db68a7821ecfd95`.

Можно посмотреть содержимое сгенерированного сикрета:

```shell
kubectl -n kube-system get secret kubeadm-certs -o yaml
```

Ну и в заключение получим путь (_join_path_), по которому будем посылать запрос на подключение.

```shell
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | cut -c9-
```

На стандартном выводе должны получить IP адрес и порт. `192.168.218.189:7443`

## Подключение дополнительных control нод

Команда для подключения control ноды будет следующая:

```
kubeadm join join_path --token join_token \
  --discovery-token-ca-cert-hash sha256:ca_cert_hash \
  --control-plane --certificate-key certificate_key
```

Подставьте свои значения и запустите команду на остальных серверах, где планируется разместить control ноды.

```shell
kubeadm join 192.168.218.189:7443 --token 8g5max.xfbtvkmud52htbmv \
  --discovery-token-ca-cert-hash sha256:41ead9594abbcfb6d8c85cbde18e91ecb39669f08b6ac4093ebfed43d7a1e588 \
  --control-plane --certificate-key 3f47da5379374fe688e92ebc93d59a58e8b3b130aca807bc9db68a7821ecfd95
```

Убедитесь, что control ноды добавлены в кластер.

```shell
kubectl get nodes
kubectl get pods -A
```

## Поправим coredns

Посмотрим, на каких нодах работают поды coredns.

```shell
kubectl -n kube-system get pods -o wide | grep coredns
```

Несмотря на то, что в Deployment корректно настроен podAntiAffinity, он не сработает до тех пор, пока в системе не появятся
новые ноды кластера и мы не перезапустим Deployment.

```shell
kubectl -n kube-system rollout restart deployment coredns
```

Убедимся, что поды DNS сервера разъехались по разным нодам кластера.

```shell
kubectl -n kube-system get pods -o wide | grep coredns
```

## Немного автоматизации

Ansible [install-another-controls.yaml](https://github.com/BigKAA/00-kube-ansible/blob/main/services/install-another-controls.yaml)