# Vault

Разнообразная документация:
* https://www.hashicorp.com/products/vault
* https://github.com/hashicorp/vault-helm
* https://www.vaultproject.io/docs/configuration/storage/postgresql

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

### Установка при помощи helm

    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    helm install --namespace vault --create-namespace vault hashicorp/vault -f values.yaml 
    
### Тем, кто не любит helm

Получаем шаблон и рихтуем его. 

    helm template vault hashicorp/vault --namespace vault -f values.yaml > manifests/00-vault.yaml
    
#### Командная строка

    kubectl create ns vault
    kubectl -n vault apply -f manifests/00-vault.yaml -f manifests/01-mwc.yaml 

#### ArgoCD

В ArgoCD один ресурс приходится исключать из синхронизации.

```yaml
    annotations:
        ## Отключаем синхронизацию в ArgoCD
        argocd.argoproj.io/hook: Skip
```

    kubectl -n vault apply -f manifests/01-mwc.yaml
    kubectl apply -f argo-app/vault-app.yaml

## Первичная настройка

    kubectl -n vault get pods

Работаем в командной строке пода vault-0.

    kubectl -n vault exec vault-0 -- vault status
    kubectl -n vault exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json

Получили ключ для unseal.

    cat cluster-keys.json | jq -r ".unseal_keys_b64[]"
    VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
    kubectl -n vault exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl -n vault exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
    
Смотрим, что поды перешли в статус Running.

    kubectl -n vault get pods

Кластер vault собран и готов к работе.
