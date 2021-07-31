#! /bin/bash

echo
echo "[ Set root passwd ]"
echo "==================="
echo root:password | chpasswd

echo
echo "[ dnf update ]"
echo "=============="
dnf update -y
