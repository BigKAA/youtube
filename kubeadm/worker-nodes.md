# Добавление worker ноды

После создания первой ноды кластера, kubeadm выведет на стандартный вывод команды для добавления новых нод.
Если не прошло больше суток после создания первой control ноды, то эти команды можно использовать для добавления нод.
Если прошло больше суток (время жизни сгенерированного токена), то придётся почитать этот раздел до конца.

Посмотреть список токенов можно следующим образом: 

```shell
kubeadm token list
```

В столбце TTL будет показано, сколько времени осталось до окончания действия токена.

## Подготовительные шаги

_На самом деле всё, что будет показано ниже можно сделать за меньшее количество шагов. Но этот пример в дальнейшем
будет легко автоматизировать._

Если нет валидного токена, создайте его (_join_token_).

```shell
kubeadm token create
```

Программа выдаст на стандартный вывод новый токен. Что-то типа: `8g5max.xfbtvkmud52htbmv`.

Нам потребуется хеш сертификата CA (_ca_cert_hash_):

```shell
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'
```

На стандартном выводе получим что-то типа: `41ead9594abbcfb6d8c85cbde18e91ecb39669f08b6ac4093ebfed43d7a1e588`.

И последнее - путь (_join_path_), по которому будем посылать запрос на подключение.

```shell
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | cut -c9-
```

На стандартном выводе должны получить IP адрес и порт. `192.168.218.189:7443`

## Подключение worker ноды

Команда для подключения ноды будет следующая:

```
kubeadm join join_path --token join_token \
  --discovery-token-ca-cert-hash sha256:ca_cert_hash 
```

Подставьте свои значения и запустите команду на остальных серверах, где планируется разместить control ноды.

```shell
kubeadm join 192.168.218.189:7443 --token 8g5max.xfbtvkmud52htbmv \
  --discovery-token-ca-cert-hash sha256:41ead9594abbcfb6d8c85cbde18e91ecb39669f08b6ac4093ebfed43d7a1e588 
```

Убедитесь, что control ноды добавлены в кластер.

```shell
kubectl get nodes
kubectl get pods -A
```

## Немного автоматизации

Ansible [install-workers.yam](https://github.com/BigKAA/00-kube-ansible/blob/main/services/install-workers.yaml)