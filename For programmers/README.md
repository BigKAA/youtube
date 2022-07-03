# Пожелания программистам и DevOps от админов эксплуатации

Мои пожелания в виде [текста на сайте](https://www.kryukov.biz/toprogrammers/).

## Простой пример программы на go

### Запуск в командной строке

    cd src
    go run cmd/main/main.go

### Запуск в docker

Сборка контейнера.
    
    docker build -t sample-go-prog:0.0.1 .

Запуск.

    docker run -d -p 8080:8080 --name sample -e "CONTEXT=/app" sample-go-prog:0.0.1

Подключение к приложению.

* Windows: http://host.docker.internal:8010/app/
* Linux: http://localhost:8010/app/
