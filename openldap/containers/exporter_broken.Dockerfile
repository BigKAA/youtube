# Не будет работать в моей конфигурации среды разработки
FROM golang:1.22.3-alpine3.20 as build

ENV CGO_ENABLED 0
ENV COOS linux

RUN git clone https://github.com/tomcz/openldap_exporter.git && pwd
RUN cd openldap_exporter && \
    go build -o /openldap_exporter ./cmd/openldap_exporter/main.go


FROM alpine:3.20.0
COPY --from=build /openldap_exporter /bin/openldap_exporter
# Не стоит помещать в контейнер сеотификат домашнего СА
# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv --- особенность использования kaniko с "левым" серитфикатом
COPY --from=build /ca.crt /ca.crt
RUN addgroup --gid 5001 --system exporter && \
    adduser --uid 5001 --system --disabled-password --ingroup exporter exporter && \
    chmod a+x /bin/openldap_exporter
USER exporter
EXPOSE 9330
CMD [ "sleep", "infinity" ]
