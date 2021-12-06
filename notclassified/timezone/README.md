# "Проблема" времени в контейнерах.

Заходим в любой контейнер и смотрим дату. Например, используем 01-openresty.yaml. 

    # date
    Mon Nov 29 09:31:56 UTC 2021

Особенность контейнеров и времени в них заключается в том, что часы в контейнере тикают точно так же,
как и на хостовой машине. Но... обычно в контейнере по умолчанию timezone UTC.

У проблемы есть два решения:

1. Забить... и учитывать то, что внутри UTC. 

Например, в конфиге того же самого [fluentbit-cm.yaml](../k8s-step-by-step/06-logs/04-fluentbit-cm.yaml), 
в parsers.conf есть поправка на время:

```
[PARSER]
    Format regex
    Name sys_log_file
    Regex (?<message>(?<time>[^ ]*\s{1,2}[^ ]*\s[^ ]*)\s(?<host>[a-zA-Z0-9_\/\.\-]*)\s.*)$
    Time_Format %b %d %H:%M:%S
    Time_Keep Off
    Time_Key time
    Time_Offset +0300
```

2. ~~Подставить файл необходимой timezone~~.

~~Во втором случае придется немного повозиться. В большинстве контейнеров просто нет необходимого набора файлов
timezone. Поэтому в качестве решения, можно подмонтировать файл timezone хостовой машины. Этот вариант демонстрируется 
в файле [02-openresty-tz.yaml](manifests/02-openresty-tz.yaml). Ниже приведен усечённый вариант файла.~~

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: openresty
spec:
  selector:
    matchLabels:
      k8s-app: openresty
  template:
    metadata:
      labels:
        k8s-app: openresty
    spec:
      containers:
        - name: openresty
          image: openresty/openresty:centos-rpm
          volumeMounts:
            - name: tz
              mountPath: /etc/localtime
      volumes:
        - name:  tz
          hostPath:
            path: /usr/share/zoneinfo/Europe/Moscow
```

2. Изменить timezone в контейнере.

Для этого, в самом контейнере должен быть установлен пакет tzdata. Если его нет, то см. пункт 1 - "Забить".

Если всё же хочется изменить timezone, тогда придется добавить в контейнер необходимый пакет. Лучше всего это сделать
на стадии создания образа, чем добавлять команду установки пакета в init контейнере пода.

Например, образ alpine идет без установленного пакета tzdata

```
docker run -it --name alpine alpine
/ # date
Mon Dec  6 07:25:57 UTC 2021
/ # ls /etc/localtime
ls: /etc/localtime: No such file or directory
/ #
```

Пример добавления пакета.

```dockerfile
FROM alpine:latest
RUN apk update && \
    apk add --no-cache tzdata
```

После того как контейнер добавлен, для смены timezone ему достаточно передать переменную среды окружения
TZ.

```
docker run -d --name opr -e "TZ=Europe/Moscow" openresty/openresty:centos-rpm
$ docker exec -it opr sh
sh-4.4# date
Mon Dec  6 10:33:25 MSK 2021
sh-4.4# ls -l /etc/localtime
lrwxrwxrwx 1 root root 25 Sep 15 17:17 /etc/localtime -> ../usr/share/zoneinfo/UTC
sh-4.4#
```

Если в контейнере не установен пакет tzdata, то определение переменной среды окружения не поможет.

```
docker run -it --name alpine -e "TZ=Europe/Moscow" alpine
/ # date
Mon Dec  6 07:36:09 UTC 2021
/ #
```

## Видео

[<img src="https://img.youtube.com/vi/2N_4jcG9dMA/maxresdefault.jpg" width="50%">](https://youtu.be/2N_4jcG9dMA)
