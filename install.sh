#!/usr/bin/env bash

curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv
echo ". $HOME/.venv/bin/activate" >> ~/.bashrc