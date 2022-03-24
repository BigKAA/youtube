#!/usr/bin/env bash
DOCKER_HUB="starter.kryukov.local"
cd
echo "Load images from files"
for I in $(ls k8s-images); do
    echo "  Load k8s-images/$I"
    docker load < k8s-images/$I
done

echo "Start tags & push images"
for IMAGE in $(docker images | sed -e '1d' | awk '{ print $1 ":" $2 }' | grep -v 'sonatype/nexus3' | grep -v kubespray | grep -v 'nginx:1.21.6-alpine')
do
    echo "==========================================================="
    if $(echo $IMAGE | grep -E '^k8s.gcr.io|^quay.io' > /dev/null); then
        TEMP=$(echo "${IMAGE##k8s.gcr.io\/}")
        NEW_IMAGE="$DOCKER_HUB/$(echo ${TEMP##quay.io\/})"
    else
        NEW_IMAGE="$DOCKER_HUB/library/$IMAGE"
    fi
    echo "$IMAGE --> $NEW_IMAGE"
    docker tag $IMAGE $NEW_IMAGE
    docker push $NEW_IMAGE
done