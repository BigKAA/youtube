FROM alpine:3.18.2

ENV KUBE_VERSION=v1.27.3
ENV HELM_VERSION=v3.12.1
ENV REGCLIENT_VERSION=v0.5.0

RUN apk --no-cache add curl jq git && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/bin/kubectl && \
    curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/bin/helm && \
    rm -rf linux-amd64

RUN curl -LO https://github.com/regclient/regclient/releases/download/${REGCLIENT_VERSION}/regctl-linux-amd64 && \
    chmod +x regctl-linux-amd64 && \
    mv regctl-linux-amd64 /usr/local/bin/regctl

CMD ["/bin/sh", "-c"]
