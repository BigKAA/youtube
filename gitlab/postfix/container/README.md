# Postfix relay

[Первоисточник](https://www.iops.tech/blog/postfix-in-alpine-docker-container/).

```shell
docker build -t bigkaa/mail-relay:0.0.1 .
```

```shell
docker run -d --rm --init \
    -e POSTFIX_SMTP_HELO_NAME=gitlab.kryukov.local \
    -e POSTFIX_MYORIGIN=gitlab.kryukov.local \
    -e POSTFIX_MYHOSTNAME=gitlab.kryukov.local \
    -e KUBER_NETWORK=10.233.0.0/16 \
    --mount type=bind,source=$(pwd)/main.cf.tmpl,target=/etc/postfix/main.cf.tmpl \
    --name mail-relay \
    -p 8025:25 \
    bigkaa/mail-relay:0.0.1
```

```shell
docker push bigkaa/mail-relay:0.0.1
```