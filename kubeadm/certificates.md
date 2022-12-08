# Обновление сертификатов

Обновление сертификатов происходит автоматически при обновлении версии кластера.

Для обновления вручную можно использовать kubeadm.

Проверка срока жизни сертификатов. 

```shell
kubeadm certs check-expiration
```

Обратите внимание, что при установке кластера при помощи kubeadm сертификаты CA выписываются на 10 лет.

Обновление сертификатов необходимо проводить на каждой control ноде кластера. Возможно обновление всех сертификатов
кластера (кроме сертификатов CA) или каждый сертификат можно обновлять отдельно.

```shell
kubeadm certs renew --help
```

Поскольку обычно все сертификаты живут около года. Что бы не вносить путаницы лучше обновить все сертификаты одной
командой.

```shell
kubeadm certs renew all
```

После обновления сертификатов вы получаете следующее сообщение:

```
You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd, 
so that they can use the new certificates.
```

Т.е. мало обновить сертификаты, необходимо еще перезапустить приложения.

```shell
mkdir ~/tmp-kube
cp -r /etc/kubernetes/manifests ~/tmp-kube
rm -f /etc/kubernetes/manifests/*
```

Ждем несколько минут и обратно включаем приложения.

```shell
cp ~/tmp-kube/manifests/* /etc/kubernetes/manifests/
```

Так же не стоит забывать про kubelet.

```shell
service restart kubelet
service status kubelet
```

Вобщем вам придётся рестартовать весь control plane и kubelet. 
Мне кажется, что проще это сделать перезагрузив ноду целиком.

```shell
kubectl drain control1.kryukov.local
reboot
```

Вы можете добавить процедуру обновления сертификатов в систему cron на 
сервере. Но не забывайте о необходимости перезапуска приложений.  