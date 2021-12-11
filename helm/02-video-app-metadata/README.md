# Видео два. Создание чарта и metadata.

Создаём чарт приложения.

    cd helm/02-video-app-metadata
    helm create openresty-art

## Структура чарта

[Документация](https://helm.sh/docs/topics/charts/)

Редактируем содержимое файла Chart.yaml.

```yaml
apiVersion: v2
name: openresty-art
description: My vision of openresty application
type: application
version: 0.1.0
appVersion: "1.19.9.1-centos-rpm"
kubeVersion: ">= 1.19.0"
```

Из директории templates удаляем не нужные файлы.

```
cd openresty-art/templates
rm -rf {tests,hpa.yaml,serviceaccount.yaml}
```

Переименовываем и переносим автоматически созданные файлы. Мы их потом удалим, но по ходу правки будем 
заимствовать из них некоторые шаблоны.
   
``` 
mkdir ../../old-templates
mv deployment.yaml ../../old-templates/deployment-orig.yaml 
mv service.yaml ../../old-templates/service-orig.yaml 
mv ingress.yaml ../../old-templates/ingress-orig.yaml
```

Скопируем манифесты нашего приложения в директорию templates

    cp ../../../base-application/* .

Теперь мы готовы начинать превращать наше приложение в Helm chart.

## Файл _helpers.tpl

Команда helm create создала шаблон _helpers.tpl, в который поместила вспомогательные (условно) функции.
Эти функции мы можем использовать в наших шаблонах.

```yaml
{{- define "openresty-art.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
```

[define](https://pkg.go.dev/text/template#hdr-Nested_template_definitions) определяет вложенные шаблоны.

В дальнейшем в любых файлах нашего чарта мы можем обратиться к такому шаблону при помощи include. Например:

```yaml
Тут будет что то вставлено: {{ include "openresty-art.chart" . }}
```

После обработки, в данном месте будет подставлено содержимое вложенного шаблона:

```yaml
Тут будет что то вставлено: {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
```

Итого в файле определено:
* **openresty-art.name** - имя чарта.
* **openresty-art.fullname** - имя приложения.
* **openresty-art.chart** - имя чарта с версией.
* **openresty-art.labels** - общий набор labels, которые можно подставлять в metadata манифестов.
* **openresty-art.selectorLabels** - набор labels, которые можно использовать в селекторах. Например, в селекторах service.
* **openresty-art.serviceAccountName** - имя SeviceAccount. При условии, что оно определено в файле values.

## Редактируем файл deployment.yaml - metadata

На данном этапе будем формировать шаблон для деплоймента. 

Рекомендую разделить в редакторе окно на две части. В левую поместить файл deployment.yaml, в правую - 
deployment-orig.yaml.

Начнём с раздела metadata.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: {{ include "openresty-art.fullname" . }}
```

В данном месте будет генерироваться имя деплоймента. 
При помощи [include](https://helm.sh/docs/chart_template_guide/named_templates/#the-include-function),
подставляется следующий шаблон:

```yaml
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

Попробуем разобраться, что тут написано.

Для начала следует понять, к каким встроенным объектам мы можем обращаться в шаблонах helm.

### Встроенные объекты

[Документация](https://helm.sh/docs/chart_template_guide/builtin_objects/)

* **Release** - описывает сам релиз.
* **Values** - значение из файла values.yaml (параметры по умолчанию).
* **Files** - доступ к файлам в чарте (кроме файлов шаблонов).
* **Capabilities** - информация о кластере kubernetes.
* **Template** - информация о текущем файле шаблона.

Разберем приведенный выше шаблон построчно.

```yaml
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
```

Оператор [if](https://pkg.go.dev/text/template#hdr-Actions) проверяет pipeline. Если pipeline возвращает 0 или
пустой объект - тогда условие = false. Иначе true.

В нашем случае используется встроенный объект Values. В файле values.yaml берется параметр объекта fullnameOverride. 
Ниже выдержка из файла values.yaml

```yaml
nameOverride: ""
fullnameOverride: ""
```

Значение не определено, значит указанный блок выполняться не будет. Если бы значение было определено, то сработал бы
шаблон

```yaml
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
```

В шаблонах, как и в командной строке shell в Linux, можно использовать pipeline. Когда результат работы одной программы, 
выдаваемый на стандартный вывод, передаётся другой программе на стандартный ввод. В данном примере значение объекта
fullnameOverride из файла values.yaml передаётся функции [trunc](https://helm.sh/docs/chart_template_guide/function_list/#trunc). 
Которая обрезает строку на 63-м символе. Значение поля name в манифесте kubernetes не должно превышать 64 символа.

Результирующее значение передаётся функции [trimSuffix](https://helm.sh/docs/chart_template_guide/function_list/#trimsuffix),
которая убирает суффиксы после символа "-" (включая сам символ).

```yaml
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
```

Если значение if false, тогда работает блок после "{{- else }}".

В нашем случае, определяется внутренняя переменная "$name". Функция [default](https://helm.sh/docs/chart_template_guide/function_list/#default)
говорит, что если не определён .Values.nameOverride, тогда использовать .Chart.Name.

.Chart.Name - это встроенный объект, содержащий имя чарта.

```yaml
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
```

Следующий оператор if вызывает функцию [contains](https://helm.sh/docs/chart_template_guide/function_list/#contains),
которая проверяет, содержит ли вторая строка первую?

Если истина, шаблон выведет содержимое .Release.Name. Обрежет его на 63-м символе. Удалит суффикс.

Иначе

```yaml
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

Будет подставлен результат работы функции printf. Обрезанный и без суффикса.

В итоге мы получаем имя деплоймента.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: {{ include "openresty-art.fullname" . }}
```

## Labels

Следующий объект раздела metadata - это метки. Для их формирования в файле _helpers.tpl определен макрос.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: {{ include "openresty-art.fullname" . }}
  labels:
    {{- include "openresty-art.labels" . | nindent 4 }}
```

openresty-art.labels формирует метки.

```yaml
{{- define "openresty-art.labels" -}}
helm.sh/chart: {{ include "openresty-art.chart" . }}
{{ include "openresty-art.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "openresty-art.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openresty-art.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Данное определение использует функции и способы, которые мы разобрали в предыдущем макросе. Поэтому подробно разбирать
эту конструкцию мы не будем. Единственная новая функция - это [quote](https://helm.sh/docs/chart_template_guide/function_list/#quote-and-squote).
Она помещает строку в двойные кавычки.

```yaml
  labels:
    {{- include "openresty-art.labels" . | nindent 4 }}
```

В этом месте подставляются метки, сгенерированные макросом. И сдвигаются ([nindent](https://helm.sh/docs/chart_template_guide/function_list/#nindent))
на 4 символа относительно начала строки. Последнее необходимо для того, что бы соблюсти синтаксис yaml файла.

## Annotations

Мы предполагаем использовать reloader.stakater.com, который перезапускает приложение, в случае изменения ConfigMap или 
Secret. Но, есть вероятность, что в вашем кластере это приложение не установлено. Эту возможность надо предусмотреть.

В файле values.yaml добавим объект application, в который мы будем помещать все параметры деплоймента. Там же
добавим объект reloader и присвоим ему значение по умолчанию false.

```yaml
application:
  reloader: false
```

В файле deployment.yaml воспользуемся этим параметром.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: {{ include "openresty-art.fullname" . }}
  labels:
    {{- include "openresty-art.labels" . | nindent 4 }}
  {{- if .Values.application.reloader }}
  annotations:
    reloader.stakater.com/auto: "true"
    configmap.reloader.stakater.com/reload: {{ include "penresty-art.fullname" . }}-conf,{{ include "penresty-art.fullname" . }}-html
  {{- end }}
```

Это конечно не идеальный вариант. Так мы отключили возможность вставлять другие аннотации в определение деплоймента.
Но на данном этапе это не важно.

```yaml
{{ include "mytestapp.fullname" . }}-conf,{{ include "mytestapp.fullname" . }}-html
```

Так мы ссылаемся на ConfigMap-ы. Шаблоны которых мы определим позднее.

## Проверка работы шаблонов

Проверим, работаю ли наши шаблоны. Для этого воспользуемся командой [template](https://helm.sh/docs/helm/helm_template/).

Перейдём в директорию, в которой находится наш чарт.

    cd ../..
    helm template app ./openresty-art --debug > app.yaml

Эта команда заставляет helm преобразовать шаблоны и выдать на стандартный вывод итоговый набор манифестов. Дополнительный
парамер --debug, заставляет программу выводить отладочную информацию, которая будет полезной в случае обнаружения
ошибок в шаблонах.

В результате формируется файл с манифестами app.yaml. Откройте его и посмотрите начало определения деплоймента.

```yaml
---
# Source: openresty-art/templates/deployment.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: app-openresty-art
  labels:
    helm.sh/chart: openresty-art-0.1.0
    app.kubernetes.io/name: openresty-art
    app.kubernetes.io/instance: app
    app.kubernetes.io/version: "1.19.9.1-centos-rpm"
    app.kubernetes.io/managed-by: Helm
```

Мы видим результат преобразования наших шаблонов. Сформировано имя приложения, раздел labels. А вот секция с
аннотациями отсутствует. Почему? Потому, что в файле values.yaml в нашем черте задано значение по умолчанию:

```yaml
application:
  reloader: false
```

### Переопределение параметров по умолчанию.

Изменить параметры по умолчанию, определённые в чарте можно двумя способами:

1. При помощи параметра --set
2. Создав и применив собственный yaml файл с переопределёнными параметрами.

Файл my-values.yaml

```yaml
fullnameOverride: "art"

application:
  reloader: true
```


```   
helm template app ./openresty-art --set "application.reloader=true" --debug > app.yaml
helm template app ./openresty-art -f my-values.yaml > app.yaml
```

### Работа с приложением.

Установим приложение.

    helm install app ./openresty-art --namespace app -f my-values.yaml
    helm list --namespace app

Удалим приложение.

    helm uninstall app --namespace app

## Видео

[<img src="https://img.youtube.com/vi/HgI_5kMhbhY/maxresdefault.jpg" width="50%">](https://youtu.be/HgI_5kMhbhY)
