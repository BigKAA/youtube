# Kafka and ssl

Обратился тут ко мне с небольшой просьбой коллега. Не могу, говорит, запустить SSL в кафке. Но не просто SSL
а так, что бы по взрослому - клиенты со своими сертификатами, серверы со своими. При этом что бы kafka к zookeeper
тоже по ssl со своим сертификатом.

В итоге у видео появился спонсор, все дружно говорим ему спасибо! :)

## Подготовка сертификатов

Мне удобно генерить сертификаты при помощи cert-manager. Поэтому 
[вот такие манифесты для сертификатов](manifests).
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

Импортирую сертификаты из кубера:

```shell
kubectl -n kafka get secrets kafka-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

kubectl -n kafka get secrets kafka-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > kafka.tls.crt
kubectl -n kafka get secrets kafka-tls -o jsonpath='{.data.tls\.key}' | base64 -d > kafka.tls.key
```

Конвертирую в pks12 и закрываю паролем.

```shell
export K_PASSWORD=PASSWORD
openssl pkcs12 -export -in kafka.tls.crt -passout pass:"$K_PASSWORD" -inkey "kafka.tls.key" -out "kafka.keystore.p12"
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

exit
```

Создаём сикрет с jks файлами:

```shell
kubectl -n kafka create secret generic kafka-client-jks --from-file=zookeeper.truststore.jks=./kafka.truststore.jks \
         --from-file=zookeeper.keystore.jks=./kafka.keystore.jks
```

### Чарт


```shell
helm -n kafka install kafka kafka-ssl -f kafka-ssl/values-k2.yaml -n kafka
```

Либо при помощи ArgoCD:

```shell
kubectl apply -f argo-app/kafka-app.yaml
```

Удаление чарта

```shell
helm uninstall kafka -n kafka
```

## Подключение клиента

### Сертификат клиента

Манифест для cermanager: [kafka-client-ssl.yaml](manifests/kafka-client-ssl.yaml).

```shell
mkdir tmp
cd tmp
```

Импортирую сертификаты из кубера:

```shell
kubectl -n kafka get secrets kafka-client1-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > kafka-client1.tls.crt
kubectl -n kafka get secrets kafka-client1-tls -o jsonpath='{.data.tls\.key}' | base64 -d > kafka-client1.tls.key
```

Конвертирую в pks12 и закрываю паролем:

```shell
export K_PASSWORD=PASSWORD
openssl pkcs12 -export -in kafka-client1.tls.crt -passout pass:"$K_PASSWORD" -inkey "kafka-client1.tls.key" -out "kafka-client1.keystore.p12"
```

Запускаем контейнер:

```shell
docker run --name jdk --rm -it -v ./:/tmp -e K_PASSWORD=$K_PASSWORD openjdk:23-jdk bash -c 'cd tmp; bash'
```

Подготовка jks файла:

```shell
keytool -importkeystore -srckeystore kafka-client1.keystore.p12 -srcstoretype PKCS12 -srcstorepass "${K_PASSWORD}" \
          -deststorepass "${K_PASSWORD}" -destkeystore "kafka-client1.keystore.jks" -noprompt

rm -f kafka-client1.keystore.p12
exit
```

Создаём сикрет с jks файлами:

```shell
kubectl -n kafka create secret generic kafka-client1-jks --from-file=kafka.truststore.jks=./kafka.truststore.jks \
         --from-file=kafka.keystore.jks=./kafka-client1.keystore.jks
```

### Kafdrop

За основу был взят чарт от [разработчика](https://github.com/obsidiandynamics/kafdrop).
Но он очень сырой, поэтому пришлось его кастомизировать.

* Добавил подключение secret с jks файлами, содержащими клиентские сертификаты и сертификат CA.
* Добавил шаблон сикрета содержащий файл `kafka.properties`. В котором хранятся пароли к jks файлам.

```shell
helm -n kafka upgrade kafka kafka-ssl -f kafka-ssl/values-k3.yaml
```

### Внешний клиент

Обновляем kafka с учетом новых параметров сервера:

```shell
helm upgrade kafka kafka-ssl -f kafka-ssl/values-k4.yaml -n kafka
```

Смотрим настройки kafka, видим что то типа: `EXTERNAL://kafka:32198`

Для клиента будем использовать сертификат, выписанный для kafdrop.

Используем клиент из дистрибутива kafka.

```shell
cd tmp
curl https://dlcdn.apache.org/kafka/3.6.1/kafka_2.13-3.6.1.tgz --output kafka_2.13-3.6.1.tgz
tar -xzf kafka_2.13-3.6.1.tgz
rm -f kafka_2.13-3.6.1.tgz
ln -s kafka_2.13-3.6.1 kafka
```

```shell
cat > client.config <<EOF
ssl.truststore.password: PASSWORD
ssl.truststore.location=./kafka.truststore.jks
ssl.keystore.password: PASSWORD
ssl.keystore.location=./kafka-client1.keystore.jks
security.protocol: SSL
EOF
```

Запускаем контейнер:

```shell
docker run --name jdk --rm -it -v ./:/tmp -e K_PASSWORD=$K_PASSWORD openjdk:23-jdk bash -c 'cd tmp; bash'
```

```shell
echo -n "192.168.218.174 kafka" >> /etc/hosts
kafka/bin/kafka-topics.sh --bootstrap-server kafka:32196 --command-config ./client.config --create --topic test-events
```
