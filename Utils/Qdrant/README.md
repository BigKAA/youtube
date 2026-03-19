# Qdrant

[Векторная база данных](https://qdrant.tech/documentation/operations/installation/).

Argo Appliction для установки в локальном кластере

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: qdrant
spec:
  destination:
    namespace: qdrant
    server: https://kubernetes.default.svc
  source:
    path: ''
    repoURL: https://qdrant.to/helm
    targetRevision: 1.17.0
    chart: qdrant
    helm:
      values: |-
        service:
          type: LoadBalancer
          annotations:
            metallb.io/loadBalancerIPs: 192.168.218.190

        persistence:
          accessModes: ["ReadWriteOnce"]
          size: 10Gi
          storageClassName: nfs-client
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      enabled: true
    syncOptions:
      - CreateNamespace=true
```
