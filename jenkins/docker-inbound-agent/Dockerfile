FROM jenkins/inbound-agent

ARG user=jenkins
USER root

RUN groupadd -g 400 agent && useradd -g 400 -u 400 -d /home/agent agent

USER ${user}
