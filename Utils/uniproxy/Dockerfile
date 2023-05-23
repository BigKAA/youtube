FROM golang:1.20.4-alpine3.18 AS build-env
ENV CGO_ENABLED 0
ENV COOS linux
ADD . /go/src/uniproxy
WORKDIR /go/src/uniproxy
RUN apk add --no-cache git && \
    go build main.go

# Final stage
FROM alpine:3.18
LABEL Author="Artur Kryukov <artur@kryukov.biz>"
EXPOSE 8080
WORKDIR /uniproxy

COPY --from=build-env /go/src/uniproxy/main /uniproxy
ENTRYPOINT /uniproxy/main