# Kafka and ssl

Обратился тут ко мне с небольшой просьбой коллега. Не могу, говорит, запустить SSL в кафке. Но не просто SSL
а так, что бы по взрослому - клиенты со своими сертификатами, серверы со своими. При этом что бы kafka к zookeeper
тоже по ssl со своим сертификатом.

В итоге у видео появился спонсор, все дружно говорим ему спасибо! :)

## Подготовка сертификатов

Мне удобно генерить сертификаты при помощи cert-manager. Поэтому 
[вот такой манифест для сертификатов](manifests/certificates.yaml).
Но вы можете подготовить файлы ключей и сертификатов при помощи утилиты openssl.

Но! Как обычно проявляются проблемы... Чарт от битнами в одном месте не умеет работать с PEM форматом! 
Причем только в одном месте не хватает маленького if... 
Поэтому есть три пути:

1. Подрихтовать скрипт в чарте и потом всю жизнь следить за обновлениями чарта.
2. Написать свой, дополнительный инит контейнер и добавлять его в values чарта.
3. Готовить сикреты с сертификатами в файлах jks вручную.

Поскольку я делаю эту работу один раз, один раз пойду по третьему пути. Но если прижмет - то сверну на 2-й :)

```shell
mkdir tmp
cd tmp
```

Импортирую сертфикаты из кубера:

```shell
kubectl -n kafka get secrets kafka-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

kubectl -n kafka get secrets kafka-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > kafka.tls.crt
kubectl -n kafka get secrets kafka-tls -o jsonpath='{.data.tls\.key}' | base64 -d > kafka.tls.key

kubectl -n kafka get secrets zoo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > zoo.tls.crt
kubectl -n kafka get secrets zoo-tls -o jsonpath='{.data.tls\.key}' | base64 -d > zoo.tls.key
```

Конвертирую в pks12 и закрываю паролем.

```shell
export K_PASSWORD=PASSWORD
openssl pkcs12 -export -in kafka.tls.crt -passout pass:"$K_PASSWORD" -inkey "kafka.tls.key" -out "kafka.keystore.p12"
openssl pkcs12 -export -in zoo.tls.crt -passout pass:"$K_PASSWORD" -inkey "zoo.tls.key" -out "zoo.keystore.p12"
```

На моей машине не установлена утилита `keytool`, поэтому буду пользоваться контейнером, который ее содержит.

```shell
docker run --name jdk --rm -it -v ./:/tmp -e K_PASSWORD=$K_PASSWORD openjdk:23-jdk bash -c 'cd tmp; bash'
```

Подготовка jks файлов:

```shell
keytool -keystore kafka.truststore.jks -alias CARoot -import -file ca.crt -storepass "${K_PASSWORD}" -noprompt
keytool -importkeystore -srckeystore kafka.keystore.p12 -srcstoretype PKCS12 -srcstorepass "${K_PASSWORD}" \
          -deststorepass "${K_PASSWORD}" -destkeystore "kafka.keystore.jks" -noprompt
rm -f kafka.keystore.p12
keytool -importkeystore -srckeystore zoo.keystore.p12 -srcstoretype PKCS12 -srcstorepass "${K_PASSWORD}" \
          -deststorepass "${K_PASSWORD}" -destkeystore "zoo.keystore.jks" -noprompt
rm -f zoo.keystore.p12

exit
```

Создаём сикреты с jks файлами:

```shell
kubectl -n kafka create secret generic kafka-jks --from-file=kafka.truststore.jks=./kafka.truststore.jks \
        --from-file=kafka.keystore.jks=./kafka.keystore.jks
kubectl -n kafka create secret generic zoo-jks --from-file=zookeeper.truststore.jks=./kafka.truststore.jks \
         --from-file=zookeeper.keystore.jks=./zoo.keystore.jks
```

### Чарт

По традиции делаю чарт "обертку" сабчартом kafka от bitnami:

```yaml
dependencies:
- name: kafka
  condition: kafka.enabled
  repository: https://charts.bitnami.com/bitnami
  version: 26.8.1
```

Файл с параметрами чарта: [values-k2.yaml](kafka-art/values-k2.yaml).

Во всех `listeners` включаем поддержку SSL и `sslClientAuth: "required"`.

```yaml
  tls:
    type: JKS
    existingSecret: "kafka-jks"
    keystorePassword: "PASSWORD"
    truststorePassword: "PASSWORD"
    zookeeper:
      enabled: true
      verifyHostname: true
      existingSecret: "zoo-jks"
      keystorePassword: "PASSWORD"
      truststorePassword: "PASSWORD"
```

Именно в `tls.zookeeper` нет поддержки PEM формата!

Конфигурация сабчарта/сабчарта zookeeper.

```yaml
  zookeeper:
    enabled: true
    replicaCount: 3
    tls:
      client:
        enabled: true
        auth: none
        existingSecret: "zoo-tls"
        keystorePassword: "PASSWORD"
        truststorePassword: "PASSWORD"
```

А вот сабчарт `zookeeper.tls.client.existingSecret` умеет только в PEM! Вот такие пироги...

Дальше просто устанавливаем чарт либо при помощи helm:

```shell
helm install kafka kafka-art -f kafka-art/values-k2.yaml -n kafka
```

Либо при помощи ArgoCD:

```shell
kubectl apply -f kafka/argo-app/kafka-app.yaml
```
