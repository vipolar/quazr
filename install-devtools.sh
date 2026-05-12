#!/bin/bash

OS_VERSION=$(lsb_release -rs)
GIT_EMAIL="miskuzius@gmail.com"
GIT_USERNAME="vipolar"
GIT_EDITOR="vim"

if [ "$OS_VERSION" != "24.04" ]; then
    echo "⚠️  ERROR: Ubuntu version is $OS_VERSION, not 24.04"
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
   echo "Running DEV installer with elevated permissions is not allowed!" 1>&2
   exit 1
fi

git config --global core.editor "$GIT_EDITOR"
git config --global user.name "$GIT_USERNAME"
git config --global user.email "$GIT_EMAIL"

sudo chmod -R 755 ./.setup-dev/

./.setup-dev/ubuntu24.sh
./.setup-dev/node24.sh
./.setup-dev/jdk25.sh
./.setup-dev/docker.sh
