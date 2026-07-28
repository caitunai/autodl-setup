#!/usr/bin/env bash

# place this file to /etc/autodl.sh
cp /root/autodl-setup/.vllmrc /root/.vllmrc
source /root/.vllmrc
cp -rf /root/autodl-setup/.bash_aliases /root/.bash_aliases
bash /root/autodl-setup/startup.sh