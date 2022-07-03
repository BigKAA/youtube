FROM golang:1.18.3-alpine3.16 AS build
ENV CGO_ENABLED 0
ENV COOS linux
ADD src /go/src/
WORKDIR /go/src
RUN go build cmd/main/main.go

# Final stage
FROM alpine:3.16.0
ENV BIND_ADDR=0.0.0.0:8080
EXPOSE 8080
RUN addgroup -g 5000 worker && \
    adduser --disabled-password --gecos "" --home "/home/worker" --uid "5000" --ingroup "worker" worker
USER worker
WORKDIR /home/worker
ADD --chown=worker:worker src/templates /home/worker/templates
COPY --from=build /go/src/main /home/worker
ENTRYPOINT /home/worker/main
