# Starter

Подготовка сервера, который в дальнейшем будет использоваться для offline установки
кластеров kubernetes при помощи kubespray.

На этом сервере должен быть установлен hub, гдн будет храниться базовый набор контейнеров и приложений kubernetes.

https://hub.docker.com/r/sonatype/nexus3/

Получаем пароль адмиина nexus

    docker exec -it nexus cat /nexus-data/admin.password

Настраиваем хранилище контейнеров в nuxus. Добавляем пользователя docker-user с паролем password

Оратите внимание на то, что у нас леый ca. Соотвественно надо настроить docker engine там где вы собираете и
пушите образыю

Логинимся в наш хаб.

    docker login --username=docker-user --password=password starter.kryukov.local

Дальше пушим образ.