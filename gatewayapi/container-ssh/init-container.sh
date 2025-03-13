#!/bin/bash

if ! id ${USER_NAME} > /dev/null 2>&1; then
    groupadd -g ${USER_ID} ${USER_NAME}
    useradd -M -s /bin/bash -u ${USER_ID} -g ${USER_ID} ${USER_NAME}
fi

/usr/sbin/sshd -D
