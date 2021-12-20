# Crunchy PostgreSQL Operator

[Документация](https://access.crunchydata.com/documentation/postgres-operator/v5/installation/helm/)

**В 5-й версии ребята порядком извратились с установкой... Ставить придется путём клонирования их git репозитория...**

## Установка оператора.

Создатели оператора ркеомендуют сначала форкнуть к себе их репозиторий:
https://github.com/CrunchyData/postgres-operator-examples/fork

Затем, локально клонировать его часть:

    git clone --depth 1 "https://github.com/BigKAA/postgres-operator-examples.git"
    cd postgres-operator-examples

И уже тут начинать менять парамеры. Я удалю не используемые файлы и директории.

Устанавливать будем при помощи helm.

В файле helm/install/values.yaml поменяем singleNamespace на true, поскольку в дальнейшем потребуется только один 
кластер и не более.

    kubectl create namespace pgo
    helm install pgo -n pgo helm/install

## Запуск экземпляра базы данных

Вешаем заразы и метки на ноды кластера. Для того, что бы приземлить базу данных на нужный сервер и запретить
деплоить на него остальные приложения.

    kubectl taint nodes db1.kryukov.local db=pgsql:NoSchedule
    kubectl label nodes db1.kryukov.local db=pgsql-main

Для определения БД можно воспользоваться helm или kustomize. Но мы будем пользоваться последним, поскольку он лучше
документирован и helm chart очень, очень, очень сырой.

Отредактируем [файл установки](postgres-operator-examples/kustomize/postgres/postgres.yaml) БД. И применим его.
Я так и не понял, зачем надо было это делать через kustomize. Ведь в файле kustomization.yaml мы определяем только
namespace.

Запустим базу данных.

    kubectl.exe apply -k kustomize/postgres

Параметры доступа к кластеру появятся в Secret pg-pguser-pg. Там определены все параметры, которые потребуются
для доступа к базе данных.
* dbname
* host
* jdbc-uri
* password
* port
* uri
* user
* verifier

## Pgadmin

