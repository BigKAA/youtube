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

2. Подставить файл необходимой timezone.

Во втором случае придется немного повозиться. В большинстве контейнеров просто нет необходимого набора файлов
timezone. Поэтому в качестве решения, можно подмонтировать файл timezone хостовой машины. Этот вариант демонстрируется 
в файле [02-openresty-tz.yaml](manifests/02-openresty-tz.yaml). Ниже приведен усечённый вариант файла.

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

