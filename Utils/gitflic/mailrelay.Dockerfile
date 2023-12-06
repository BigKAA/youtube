FROM alpine:3.18.2
ENV DOCKERIZE_VERSION v0.7.0

# install packages
RUN apk add --no-cache --update postfix bash && \
    apk add --no-cache --upgrade musl musl-utils && \
    (rm "/tmp/"* 2>/dev/null || true) && (rm -rf /var/cache/apk/* 2>/dev/null || true)

# install dockerize
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# postfix is listening on port 25
EXPOSE 25
STOPSIGNAL SIGKILL

CMD ["dockerize", "-template", "/etc/postfix/main.cf.tmpl:/etc/postfix/main.cf", "postfix", "start-fg"]