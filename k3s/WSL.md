# K3S в WSL2

Установка K3S в WSL2.

За основу берём дистрибутив Ubuntu.

Kubernetes плохо работает с nftables, который теперь используется по умолчанию в Ubuntu, поэтому 
вернемся к устаревшему режиму iptables:

```shell
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
```

Выбираем нужную версию k3s на Github https://github.com/k3s-io/k3s/releases

```shell
wget https://github.com/k3s-io/k3s/releases/download/v1.24.4%2Bk3s1/k3s
sudo mv k3s /usr/local/bin
sudo chmod a+x /usr/local/bin/k3s
k3s --version
sudo k3s check-config
```
	
Запускаем сервер:
	
```shell
sudo k3s server --write-kubeconfig-mode 644
```

Вариант запуска в скрине:

```shell
screen -d -m -L -Logfile /var/log/k3s.log /usr/local/bin/k3s server --write-kubeconfig-mode 644
```

Подготавливаем окружение для работы:

```shell
export KUBERNETES_MASTER=$( grep server: /etc/rancher/k3s/k3s.yaml | cut -c13-)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBERNETES_MASTER=$( grep server: /etc/rancher/k3s/k3s.yaml | cut -c13-)" >> ~/.bashrc
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
alias kubectl="k3s kubectl"
echo 'alias kubectl="k3s kubectl"' >> ~/.bashrc
```

## Видео

* Youtube: https://youtu.be/TKGGsvNFMZA
* Telegram: https://t.me/arturkryukov/64
* VK: https://vk.com/video7111833_456239203