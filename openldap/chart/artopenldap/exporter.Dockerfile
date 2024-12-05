FROM alpine:3.20.0

# from cache folder
COPY out/openldap_exporter /bin/openldap_exporter
RUN addgroup --gid 5001 --system exporter && \
    adduser --uid 5001 --system --disabled-password --ingroup exporter exporter && \
    chmod a+x /bin/openldap_exporter
USER exporter
EXPOSE 9330

CMD [ "/bin/openldap_exporter", "--jsonLog" ]
