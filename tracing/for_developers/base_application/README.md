# Базовое приложение

Базовое приложение находится в директории [base_application](). Оно состоит из двух программ: application1 и application2.

Обе программы реализуют "некое" REST API. 

## application1

Исходный код [application1](application1/application1.py).

Файл [requirements.txt](application1/requirements.txt).

Слушает запросы на всех сетевых интерфейсах на порту 5000 (значение по умолчанию Flask).

```python
if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

```python
@app.route("/")
@app.route("/index.html")
def root():
    return render_template("index.html")

@app.route("/api/v1/base")
def base():
    resp = requests.get(f"{os.getenv('APP2')}/api/v1/data")
    # Добавим случайную задержку
    delay: float = random.uniform(0.1, 0.9)
    time.sleep(delay)
    return resp.json()
```

При запросе на `/` или `/index.html` отдаёт файл `templates/index.html`.

`/api/v1/base` - эмулирует запрос к некоему API. Функция `base` посылает HTTP запрос во второе приложение. Получает
от него ответ.

Затем генерируется случайная задержка, для эмуляции задержки обработки запроса приложением application1. Результат
обращения к application2 отдаётся клиенту.

```python
resp = requests.get(f"{os.getenv('APP2')}/api/v1/data")
```

Для указания, куда посылать запросы необходимо использовать переменную среды окружения `APP2`. В качестве значения
используется следующий формат: `http://application2:5000`.

Для сборки контейнера применяется [Dockerfile](application1/Dockerfile).

## application2

Исходный код [application1](application2/application2.py).

Файл [requirements.txt](application2/requirements.txt).

Слушает запросы на всех сетевых интерфейсах на порту 5000 (значения по умолчанию).

```python
if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

Непосредственно в коде определены данные, которые приложение выдаёт клиенту по запросу:

```python
data = [
    {
        "id": 1,
        "name": "Delay 1",
        "value": 12.1,
    },
    {
        "id": 2,
        "name": "Delay 2",
        "value": 23.1,
    }
]
```

Клиент будет посылать запросы на один метод API, эмулирующий запрос к "базе данных":

```python
@app.route("/api/v1/data")
def db_request_emulation():
    # generate 1-st delay and value
    delay: float = random.uniform(0.1, 0.9)
    time.sleep(delay)
    data[0]['value'] = delay

    # generate 2-nd delay and value
    delay: float = random.uniform(0.1, 0.9)
    time.sleep(delay)
    data[1]['value'] = delay
    return jsonify({'data': data})
```

По аналогии с application1, формируются случайные задержки эмулирующие задержки при обращении к БД.

## docker-compose

Для сборки контейнеров и запуска приложений используется файл [docker-compose.yaml](docker-compose.yaml).

```shell
cd base_application
docker-compose up -d
```

### Прокси

Перед приложением application1 ставится прокси, реализованный при помощи nginx:

```yaml
  nginx:
    image: nginx:1.23.3
    ports:
      - "8080:80"
    volumes:
      - ${PWD}/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ${PWD}/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf
```

Конфигурационные файлы nginx находятся в директории [base_application/nginx](nginx).

```nginx configuration
location / {
        proxy_pass http://application1:5000/;
    }
```

Для доступа к приложению в браузере введите [http://127.0.0.1:8080](http://127.0.0.1:8080).

### application1

Запуск приложения application1:

```yaml
  application1:
    image: application1:v0.0.1
    build:
      context: application1
    ports:
      - "5001:5000"
    environment:
      APP2: "http://application2:5000"
```

Можно было не публиковать порт приложения наружу. Ограничившись `EXPOSE`. Но для тестирования выставим приложение
на пот 5001. Что бы можно было посылать запросы напрямую.

Для доступа к application1 в браузере введите [http://127.0.0.1:5001](http://127.0.0.1:5001).

### application2

Запуск приложения application2:

```yaml
  application2:
    image: application2:v0.0.1
    build:
      context: application2
    ports:
      - "5002:5000"
```

Для доступа к application2 в браузере введите [http://127.0.0.1:5002/api/v1/data](http://127.0.0.1:5002/api/v1/data).