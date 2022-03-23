#!/usr/bin/env bash
NEXUS=nexus.kryukov.local
SRC_DIR=/root/docker-images
KUBE_VERSION=v1.23.5
cd

for FILE in $( ls $SRC_DIR )
do
    if [ -f $SRC_DIR/$FILE ]; then
        echo "upload $SRC_DIR/$FILE"
        curl -v -u docker-user:password --upload-file $SRC_DIR/$FILE http://$NEXUS/repository/files/k8s/$KUBE_VERSION/$FILE
    fi
done