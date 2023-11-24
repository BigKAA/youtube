# Calico eBPF

������ ��� ����������, ��������� - ����� �� ���������� �� eBPF �� ������������ kubernetes proxy � ipvs?

Pros:

- �� �������� ��������� ��������� ������� � ������� �������� �� CPU ��� ������������� �������� kubernetes 
  (������ kubernetes proxy).
- ������� �������� �� CPU � �������� ��� ��������� ������ Network Polices.
- ����������� service mesh.

Contras:

- �� ����� ������� ������� (����� ������).
- �� ����� ������ � ��������� ���������.
- �� ����� ������ ��� ����� ���������� Network Polices. 

## ��� ����� eBPF

[eBPF](https://ebpf.io/) - ��� ����������, ������� ����� ��������� ��������� � ����������������� ���������, ���� 
Linux. ��� ����������� �������� ��������� ������.

��� ���������� ��������, ���������� �� ����������� ����� ����������������, � ���� Linux ����������� ����������� ������.

����� ��������� ��������� � ����������� ������ ���������� �� ������������ ��������, �� ����� ������� �����������
����������� ������ ����. ���� ���������� ����� �������� � ����, ��������� ��� ���� ������� ��������� ������ �� ������ 
���� - ��� �� ����� ��������.

��� ePBF ���������� � ����� ������ ������ � ������� ������ ����. ���� Linux ��������� ����� �� ������ ������� �
������� ����� ���������� ������� ������������, � ������� � ��� ������� �������������� �����. ��� ��������
��������� ��������� NAT � Network Polices �� ������� ����.

## Calico � eBPF

Calico ������������ ��� ���������� ��� ����������� ������ �������� (NAT ��������������): iptables, ipvs � ePBF.

Iptables �������� ����� ��������� � �� ��������������� ��� ��������� �������� ���������� ��������������. ������� ���
������ ����������� �� ����������.

ipvs �������� � �������� ��������� �������. ��������� ����������� ����������� ������� ���������. � ����������� �������
ipvs ������� ��� ������ ���� ��������. �� ���� ����� �� ������������� ��� ���� ��������� - �� ��������� ��� ��� ������� 
�� ePBF.

��� ��������� ePBF �� calico ���������� ��������� kube-proxy, calico ����� �� ���� ������� NAT. ������� � ipvs 
�� eBPF �� ���������� �������� ����� �������� ������� ������. ������� - �� ���� ���������� �� eBPF �� ���������� 
��������. ���������� �� ��������� ����������� ��� ��������. ��������� ����� ����� ������� � ���������� ���������� ��
����.

��� �� ���������� ����������, ����� 
[��������� � ������������ kubernetes ��������������](https://docs.tigera.io/calico/latest/operations/ebpf/enabling-ebpf#supported).

### ������� �� eBPF �������� ��������

��������� �� ����� �������� �� eBPF ����� �������� kube-proxy, ������������ �������� ��� �������� �������� ������
����������� � kubernetes API. ����������, ��� ������� ����� ���������� `kubectl cluster-info`

```shell
kubectl cluster-info
```

```
Kubernetes control plane is running at https://192.168.218.171:6443
```

Calico � ���� �������� ��� ���������� ��� ������ ���������. ������� ��� ���������� �������� ConfigMap.

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: tigera-operator
data:
  KUBERNETES_SERVICE_HOST: '192.168.218.171'
  KUBERNETES_SERVICE_PORT: '6443'
```

���� ��������� ����� ���� ���������� ���� calico-node �� ���� ����� ��������.

�������������� kube-proxy ���, ��� �� �� ���������� ������ �� ����� � label `non-calico": true`.

```shell
kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'
```

� namespace kube-system ����� ������� ���� kube-proxy.

�������� ����� eBPF.

```shell
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"BPF"}}}'
```

������������ ���������� ��������� �������� � ������ ������. ��� �� ��� ������� �� eBPF ���������� ������������ ������ 
���� ��������.

���������, ��� ����� �������� ���� � ��� ��� ������������ ���������� ipvs.

```shell
ip a s
```

������ ��������� ������������� ����������. ��������, � ���� �� �������� ������ `kubernetes.default.svc`, �������������
������� ���� �� ��������.

**� ��� ����� � �� ��� �����?**

## ��������� ��� ������ calico operator

��������� ������ ���: https://docs.tigera.io/calico/latest/operations/ebpf/install

� ���� ������ �� ����������. ���� calico-node ��������� ������������. ��������� ���� ����� �����, ��� ��������
� felix. 

```
+---------------------------+---------+----------------+---------------------+--------+
|         COMPONENT         | TIMEOUT |    LIVENESS    |      READINESS      | DETAIL |
+---------------------------+---------+----------------+---------------------+--------+
| CalculationGraph          | 30s     | reporting live | reporting ready     |        |
| FelixStartup              | -       | reporting live | reporting ready     |        |
| InternalDataplaneMainLoop | 1m30s   | reporting live | reporting non-ready |        |
```

��� � ������� ������ ��� ��������� � ������� ����������. � ���� �� ������������ readnessProbe.

```
# calico-node -felix-ready
calico/node is not ready: felix is not ready: readiness probe reporting 503
```

� ������� ����� ����� ��� ��������. �� ��� � �� ����� ��� �� ��� ���������. �������� ��������� ����� � ��������� 
������������ ����������. � ��������� ��� ����������, ��� ��������� - **��� ���������� �������**.
� [����� ������������](https://youtu.be/Ta7ZiqAJD78).

## � ����� �� ����������

����� ���� ������ calico ������� ����������� ������� ���������� �� ����������. ����� ������ ��������� ����� ��������.

_��� ���������� �������� � ���������������� ����� ����� ����� � [����](https://github.com/BigKAA/00-kube-ansible) 
��������_.

������������� calico bpf ���� ������ �� ����� ��������, � ������ ��� �������������� ���������.

� ���������� ��� **��** ����������� kube-proxy, ��������� ��� nat �������������� ������ �� ���� calico bpf. �������
��������� ��� ��������� �� ����� ������������� ������ ����.  

```shell
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml --skip-phases=addon/kube-proxy
```

��������� nodelocaldns (_����� ��� ���������� �������, ���������������� ����� � ���� � ���, ����� �� ��������_):

```shell
kubectl apply -f /etc/kubernetes/nodelocaldns-daemonset.yaml
```

��������� kube-proxy �� ����������, ������� ConfigMap ����������� ��� ���������� ������ calico, ���������� ����������
����������� �� ����� ����������� � kubernetes API.

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: kube-system
data:
  KUBERNETES_SERVICE_HOST: "192.168.218.171"
  KUBERNETES_SERVICE_PORT: "6443"
```

```shell
kubectl apply -f /etc/kubernetes/kubernetes-services-endpoint.yaml
```

������� �������� calico.

```shell
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/calico-typha.yaml -o calico.yaml
```

�����������. ���� `- name: CALICO_IPV4POOL_CIDR`, � `value` ����������� CIDR.

��� �� ������ ����� VXLAN, ��������� ����� IPIP � ������ BPF �������� � �������� �� ����.

```yaml
            # Enable IPIP
            - name: CALICO_IPV4POOL_IPIP
              value: "Never"
            # Enable or Disable VXLAN on the default IP pool.
            - name: CALICO_IPV4POOL_VXLAN
              value: "Always"
```

��������� ��������:

```shell
kubectl apply -f calico.yaml
```

������������� ������� `calicoctl`:

```shell
curl -L https://github.com/projectcalico/calico/releases/download/v3.26.4/calicoctl-linux-amd64 -o calicoctl
chmod +x ./calicoctl
mv calicoctl /usr/local/bin
```

�� ������ ������ � ��� BPF ��� �� �������. �������� ���, ������� �������� `bpfEnabled: true` � FelixConfiguration:

```yaml
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfLogLevel: ""
  floatingIPs: Disabled
  logSeverityScreen: Info
  reportingInterval: 0s
  bpfEnabled: true
```

```shell
calicoctl apply -f felix-configuration.yaml
```

��������� ��������� ���� � ��������.

���� ����� ���������� ��� ���� � namespace `kube-system`.

```shell
watch kubectl -n kube-system get pods
```

������� � ����� ��� calico-node � ����������, ��� NAT �������������� ��������� � BPF.

```shell
kubectl -n kube-system get pods | grep node
```

```shell
kubectl exec -it -n kube-system calico-node-5j8cm -- bash
```

������ ���� ��������� �������:

```shell
calico-node -bpf nat dump
```