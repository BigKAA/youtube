FROM alpine:3.19.1

ARG KUBE_VERSION
ARG HELM_VERSION
ARG REGCLIENT_VERSION
ARG KUBECONFORM_VERSION

RUN apk --no-cache add curl jq git && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/bin/kubectl && \
    curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    tar -zxf helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/bin/helm && \
    rm -rf linux-amd64 && \
    curl -LO https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz && \
    tar -zxf kubeconform-linux-amd64.tar.gz && \
    mv kubeconform /usr/bin && \
    rm -rf kubeconform LICENSE kubeconform-linux-amd64.tar.gz

RUN curl -LO https://github.com/regclient/regclient/releases/download/${REGCLIENT_VERSION}/regctl-linux-amd64 && \
    chmod +x regctl-linux-amd64 && \
    mv regctl-linux-amd64 /usr/local/bin/regctl

CMD ["/bin/sh", "-c"]
