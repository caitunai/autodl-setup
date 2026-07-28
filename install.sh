#!/usr/bin/env bash

curl -LsSf https://astral.sh/uv/install.sh | sh
cp ./.vllmrc ~/.vllmrc
echo ". $HOME/.venv/bin/activate" >> ~/.bashrc
echo ". $HOME/.vllmrc" >> ~/.bashrc

. $HOME/.bashrc
uv venv
. $HOME/.bashrc

apt-get update
apt-get -y install pkg-config libopus-dev libopusfile-dev ffmpeg
