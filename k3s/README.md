# K3S

K3s - это полностью совместимый дистрибутив Kubernetes

## firewall

```shell
firewall-cmd --permanent --zone=public --add-port=6443/tcp
firewall-cmd --permanent --zone=public --add-port=8472/udp
firewall-cmd --permanent --zone=public --add-port=51820/tcp
firewall-cmd --permanent --zone=public --add-port=51821/tcp
firewall-cmd --permanent --zone=public --add-port=10250/tcp
firewall-cmd --permanent --zone=public --add-port=2379-2380/tcp
firewall-cmd --complete-reload
```

