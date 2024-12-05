FROM rockylinux:8.9-minimal

RUN microdnf update -y && microdnf -y install tar procps-ng curl wget git perl-Archive-Zip && \
    wget -q https://repo.symas.com/configs/SOFL/rhel8/sofl.repo -O /etc/yum.repos.d/sofl.repo && \
    microdnf install -y symas-openldap-clients symas-openldap-servers && \
    mkdir -p /var/lib/openldap && \
    chown -R ldap:ldap /etc/openldap /var/lib/openldap

EXPOSE 10389
USER ldap

CMD [ "sleep", "infinity" ]
