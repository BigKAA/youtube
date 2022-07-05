# Пример деплоя kafka

Задача: 
1. Настроить kafaka.
2. Настроить сборщик логов fluentbit на передачу логов в kafka.
3. Настроить [vector](https://vector.dev/docs) логи из kafka и сохранять их в файловой системе на nfs диске.

## Установка kafka

За основу берём чарт от [Bitnami](https://github.com/bitnami/charts/tree/master/bitnami/kafka).

[WEB интерфейс](https://github.com/obsidiandynamics/kafdrop) для kafka.

