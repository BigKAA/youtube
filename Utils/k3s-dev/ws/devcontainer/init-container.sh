#!/bin/bash

if ! id ${USER_NAME} > /dev/null 2>&1; then
    groupadd -g ${USER_ID} ${USER_NAME}
    useradd -M -s /bin/bash -u ${USER_ID} -g ${USER_ID} ${USER_NAME}
fi

if [ -f /usr/local/share/dev-ca.crt ]; then
    mkdir /usr/local/share/ca-certificates/extra
    cp /usr/local/share/dev-ca.crt /usr/local/share/ca-certificates/extra/dev-ca.crt
    update-ca-certificates
fi

/usr/sbin/sshd -D
