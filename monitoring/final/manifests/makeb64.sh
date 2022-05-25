#! /bin/bash

KUBECTL=kubectl
which kubectl > /dev/null 2>&1
if [ $? -ne 0 ]; then
    which kubectl.exe > /dev/null 2>&1
    if [ $? -eq 0 ]; then
       KUBECTL=kubectl.exe
    else
      echo "Can't find kubectl"
      exit 1
    fi
fi

cd dashboards
for FILE in *.json; do
  gzip -c $FILE | base64 > $FILE.gz.b64
  $KUBECTL create cm ${FILE%.json} --from-file=${FILE}.gz.b64 --dry-run=client -o yaml | sed '/creationTimestamp/d'> ../manifests/grafana/cm_${FILE%.json}.yaml
  rm -f $FILE.gz.b64
done