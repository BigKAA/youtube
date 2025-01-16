FROM alpine:3.20.3
RUN addgroup -g 1000 -S testroup && adduser -u 1000 -S testuser -G testroup

