#!/bin/bash

if [[ $EUID -eq 0 ]]; then
   echo "Running Ubuntu 24.04 installer with elevated permissions is not allowed!" 1>&2
   exit 1
fi

sudo apt install -y git gpg wget curl build-essential ca-certificates apt-transport-https
