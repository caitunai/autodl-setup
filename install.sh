#!/usr/bin/env bash

curl -LsSf https://astral.sh/uv/install.sh | sh
. $HOME/.bashrc
uv venv
echo ". $HOME/.venv/bin/activate" >> ~/.bashrc

cp ./.vllmrc ~/.vllmrc
echo ". $HOME/.vllmrc" >> ~/.bashrc
. $HOME/.bashrc

apt-get update
apt-get -y install pkg-config libopus-dev libopusfile-dev ffmpeg
