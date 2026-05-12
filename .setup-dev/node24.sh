#!/bin/bash

if [[ $EUID -eq 0 ]]; then
   echo "Running Node24 installer with elevated permissions is not allowed!" 1>&2
   exit 1
fi

NVM_VER=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep tag_name | cut -d \" -f4)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VER}/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install 24
nvm alias default 24