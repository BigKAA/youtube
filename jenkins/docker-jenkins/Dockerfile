FROM jenkins/jenkins:lts-centos

RUN /usr/local/bin/install-plugins.sh kubernetes &&\
    /usr/local/bin/install-plugins.sh kubernetes-cd &&\
    /usr/local/bin/install-plugins.sh workflow-job &&\
    /usr/local/bin/install-plugins.sh workflow-aggregator &&\
    /usr/local/bin/install-plugins.sh credentials-binding &&\
    /usr/local/bin/install-plugins.sh credentials-binding configuration-as-code &&\
    /usr/local/bin/install-plugins.sh git &&\
    /usr/local/bin/install-plugins.sh dark-theme &&\
    /usr/local/bin/install-plugins.sh prometheus &&\
    /usr/local/bin/install-plugins.sh nexus-jenkins
