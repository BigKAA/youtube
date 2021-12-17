# Видео пять. ConfigMap

В директории templates есть два файла с ConfigMap:
* configmap-conf.yaml - содержит конфигурационный файл default.conf.
* configmap-html.yaml - содержит html файлы.

Посмотрим как эти файлы можно использовать в шаблонах.

## Вариант раз

Файлы, которые находятся непосредственно в ConfigMaps, неудобно редактировать.
Редакторы теряются в формате. Например, в configmap-html.yaml основной
формат - yaml, а формат вложенных файлов html.

Было бы неплохо, вынести содержимое вложенных файлов в отдельный файл.
А в шаблоне, в нужном месте вставлять его содержимое.

### configmap-conf.yaml

Начнём с конфигурационного файла приложения. В директории openresty-art
создадим файл default.conf и поместим в него конфигурационные параметры
openresty.

В файле configmap-conf.yaml удалим содержимое секции data и 
вставим следующий шаблон.

```yaml
data:
  default.conf: |-
{{ .Files.Get "default.conf" | indent 4 }}
```

В шаблоне мы использовали встроенный объект Files. При помощи которого
мы можем работать с файлами, находящимися внутри чарта.

При помощи функции Get получаем содержимое файла default.conf. Сдвигаем
каждую строку на 4 символа. Шаблон должен быть помещен строго в начало
строки.

Проверим, работает шаблон или нет.

    helm template app ./openresty-art/ -f my-values.yaml > app.yaml

### configmap-html.yaml

В директории openresty-art создадим директорию html. В которой добавим
два файла: 50x.html и index.html

В фале configmap-html.yaml удалим все в разделе data и добавим следующий
шаблон:

```yaml
data:
{{- range $path, $_ :=  .Files.Glob  "html/*" }}
  {{ base $path }}: |
{{ $.Files.Get $path | indent 4 }}
{{- end }}
```

При помощи функции [Glob](https://pkg.go.dev/github.com/gobwas/glob) 
мы получаем список файлов из указанной директории, подходящих под шаблон.
При помощи range перебираем его. В каждой итерации в переменной %path получаем 
путь к файлу.

Функция [base](https://pkg.go.dev/path#example-Base) возвращает имя файла.

$.Files.Get читает его содержимое.

В итоге, в configMap мы получим столько файлов, сколько их есть в директории
html.

Проверяем:

    helm template app ./openresty-art/ -f my-values.yaml > app.yaml

Вроде бы всё хорошо, но при использовании .Files мы не сможем изменить 
содержимое файлов при помощи кастомных файлов values и параметров --set.
Во всяком случае мне такой способ не известен.

### Вариант два.

Добавить содержимое файлов в файл values.yaml.

```yaml
conf:
  defaultConf: |-
    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /usr/local/openresty/nginx/html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/local/openresty/nginx/html;
        }
    }
html:
  index: |-
    <html>
      <head>
        <title>Тестовая страница</title>
        <meta charset="UTF-8">
      </head>
      <body>
        <h1>Тестовая страница</h1>
      </body>
    </html>
  50x: |-
    <!DOCTYPE html>
    <html>
    <head>
    <meta content="text/html;charset=utf-8" http-equiv="Content-Type">
    <meta content="utf-8" http-equiv="encoding">
    <title>Error</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
    </head>
    <body>
    <h1>An error occurred.</h1>
    <p>Sorry, the page you are looking for is currently unavailable.<br/>
    Please try again later.</p>
    </body>
    </html>
```

В файле configmap-conf.yaml нам необходимо подставить всего один файл с
известным именем. Поэтому шаблон будет простой.

```yaml
data:
  default.conf: |-
{{ .Values.conf.defaultConf | indent 4 }}
```

В файле configmap-html.yaml, количество html файлов заранее не известно.
Поэтому шаблон будет чуть сложнее.

```yaml
data:
{{- range $file, $value :=  .Values.html }}
  {{ $file }}.html: |
{{ $value | indent 4 }}
{{- end }}
```

Проверяем работу шаблона по умолчанию:

    helm template app ./openresty-art/ -f my-values.yaml > app.yaml

Теперь посмотрим, как подставить свои файлы, при вызове helm.
Создадим в директории 05-video-cm директорию html и поместим в неё
файла index.html, попутно нмного его изменив. Что бы он отличался
от файла index.html файла values.yaml.

Сначала подставим только my-default.conf:

    helm template app ./openresty-art/ -f my-values.yaml \
    --set-file conf.defaultConf=my-default.conf  > app.yaml

А теперь изменим html/index.html:

    helm template app ./openresty-art/ -f my-values.yaml \
    --set-file conf.defaultConf=my-default.conf \
    --set-file html.index=html/index.html > app.yaml

Добавим 3-й html файл:

    helm template app ./openresty-art/ -f my-values.yaml \
    --set-file conf.defaultConf=my-default.conf \
    --set-file html.test=html/index.html > app.yaml

## Видео

[<img src="https://img.youtube.com/vi/rb_qifNyDdA/maxresdefault.jpg" width="50%">](https://youtu.be/rb_qifNyDdA)
