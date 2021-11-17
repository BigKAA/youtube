# Vault

Разнообразная документация:
* https://www.hashicorp.com/products/vault
* https://github.com/hashicorp/vault-helm
* https://www.vaultproject.io/docs/configuration/storage/postgresql
* https://github.com/kubernetes-sigs/secrets-store-csi-driver/

## Установка


### Хранилище данных

По умолчанию helm chart vault для хранения данных устанавливает Consul. Поскольку у нас в кластере уже
установлен [PostgreSQL](../base/Crunchy%20PostgreSQL%20Operator), будем использовать его вместо Consul.

_Первоначально хотел использовать как хранилище minio, но к сожалению storage s3 не умеет работать в HA режиме_. 

В PostgreeSQL:
* Добавляем пользователя vault.
* Cоздаем базу vault и добавляем в нее таблицы.
* Предоставляем права доступа пользователю vault на базу и таблицы.

```sql
CREATE TABLE vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT pkey PRIMARY KEY (path, key)
);

CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);

CREATE TABLE vault_ha_locks (
  ha_key                                      TEXT COLLATE "C" NOT NULL,
  ha_identity                                 TEXT COLLATE "C" NOT NULL,
  ha_value                                    TEXT COLLATE "C",
  valid_until                                 TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT ha_key PRIMARY KEY (ha_key)
);
```

### values file

Подготавливаем файл [values.yaml](values.yaml) с учетом того, что vault будет работать в режиме HA и в качестве
хранилища используется PostgreSQL, установленный в нашем же кластере.

### helm install

    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    helm install --namespace vault --create-namespace vault hashicorp/vault -f values.yaml 
    
### ArgoCD install

    kubectl apply -f argo-app/vault-app.yaml

## Secrets store CSI driver

Потребуется для подключения сикретов из vault в init контейнеры.

### helm install

    helm repo add secrets-store-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts
    helm repo update
    helm install --namespace vault csi secrets-store-csi-driver/secrets-store-csi-driver 

### ArgoCD install

    kubectl apply -f argo-app/csi-app.yaml

## Первичная настройка

    kubectl -n vault get pods

Работаем в командной строке пода vault-0.

    kubectl -n vault exec vault-0 -- vault status
    kubectl -n vault exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json

Получили ключ для unseal.

    cat cluster-keys.json | jq -r ".unseal_keys_b64[]"

Ключ сохраняем где-то в сейфе. Потому как он будет необходим при каждом запуске
пода vault.

    VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
    kubectl -n vault exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl -n vault exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
    
Смотрим, что поды перешли в статус Running.

    kubectl -n vault get pods

Кластер vault собран и готов к работе.

## Использование vault в приложении.

     cat cluster-keys.json | jq -r ".root_token"

Запоминаем токен

    kubectl -n vault exec -it vault-0 -- /bin/sh
    vault login

Подставляем токен.

    vault secrets enable -path=secret kv-v2
    vault auth enable kubernetes
    vault auth list

    vault write auth/kubernetes/config \
        kubernetes_host="https://kubernetes.default.svc:443" \
        token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
        issuer="https://kubernetes.default.svc.cluster.local"

Добавляем секрет

    vault kv put secret/application application="HelloPassword" user="Vasiliy" password="MegaPassword"
    vault kv get secret/application

    vault policy write internal-app - <<EOF
    path "secret/data/application" {
      capabilities = ["read"]
    }
    EOF
    vault policy read internal-app

    vault write auth/kubernetes/role/application \
    bound_service_account_names=application-sa \
    bound_service_account_namespaces=default \
    policies=internal-app \
    ttl=20m

## Видео

[<img src="https://img.youtube.com/vi/3zqjAqWH6Sw/maxresdefault.jpg" width="50%">](https://youtu.be/3zqjAqWH6Sw)