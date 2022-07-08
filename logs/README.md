# Пример деплоя kafka

В систему очень сильно увеличилось количество приложений. Поток логов растёт со страшной силой.
Elasticsearch пыхтит на грани возможного. Необходимо сделать процесс добавление логов в elastic асинхронным.

Задача: 
1. Настроить kafaka.
2. Настроить сборщик логов fluentbit на передачу логов в kafka.
3. Настроить [vector](https://vector.dev/docs) забирать логи из kafka и сохранять их elasticsearch.

За основу берём чарты:
* от Bitnami:
  * [Kafka](https://github.com/bitnami/charts/tree/master/bitnami/kafka).
  * [elasticsearch](https://github.com/bitnami/charts/tree/master/bitnami/elasticsearch).
* [vector](https://helm.vector.dev).
* [fluentbit](https://fluent.github.io/helm-charts).

[WEB интерфейс](https://github.com/obsidiandynamics/kafdrop) для kafka. Мне их чарт не понравился. Поэтому малость его
модифицировал и [положил тут](charts/kafdrop).

