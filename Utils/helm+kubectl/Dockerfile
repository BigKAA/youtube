FROM alpine:3.14.2

RUN apk --no-cache add curl && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubect && \
    curl -LO https://get.helm.sh/helm-v3.6.2-linux-amd64.tar.gz && \
    tar -zxvf helm-v3.6.2-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64

CMD ["/bin/sh"]