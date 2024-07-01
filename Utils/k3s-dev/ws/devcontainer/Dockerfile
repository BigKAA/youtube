FROM ubuntu:24.04

COPY init-container.sh /usr/local/bin/init-container.sh
RUN apt-get update && apt-get install -y openssh-server vim mc tar git && \
    chmod +x /usr/local/bin/init-container.sh

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/init-container.sh"]
