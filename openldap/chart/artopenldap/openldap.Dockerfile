FROM alpine:3.20.0

RUN apk add --update openldap \
    openldap-backend-all \
    openldap-overlay-all \
    openldap-clients \
    openldap-passwd-sha2 \
    wget curl git tar && \
    chown -R ldap:ldap /etc/openldap /var/lib/openldap

# Стартовые скрипты пишите под себя сами :)    
# COPY --chmod=755 start.sh /start.sh
EXPOSE 10389

USER ldap

CMD [ "sleep", "infinity" ]
