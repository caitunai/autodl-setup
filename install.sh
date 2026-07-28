#!/usr/bin/env bash

# ==========================================
# 第一部分：仅在 uv 不存在时进行安装与配置
# ==========================================
if ! command -v uv >/dev/null 2>&1; then
    echo "未检测到 uv，开始安装..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # 临时把 uv 路径引入当前环境，避免找不到 uv 命令
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
    
    # 创建虚拟环境
    uv venv
    
    # 检查并添加虚拟环境激活脚本到 .bashrc（防重复）
    ACTIVATE_CMD=". $HOME/.venv/bin/activate"
    if ! grep -Fq "$ACTIVATE_CMD" ~/.bashrc; then
        echo "$ACTIVATE_CMD" >> ~/.bashrc
    fi
else
    echo "uv 已安装，跳过安装步骤。"
fi

cp ./.vllmrc ~/.vllmrc
# ==========================================
# 第二部分：复制配置并避免重复添加到 .bashrc
# ==========================================
# 检查 .bashrc 中是否已经包含引入命令
VLLMRC_CMD=". $HOME/.vllmrc"
if ! grep -Fq "$VLLMRC_CMD" ~/.bashrc; then
    echo "$VLLMRC_CMD" >> ~/.bashrc
    echo "已将 .vllmrc 引入代码追加到 ~/.bashrc"
else
    echo ".vllmrc 已存在于 ~/.bashrc 中，跳过追加。"
fi

. $HOME/.bashrc

apt-get update
apt-get -y install pkg-config libopus-dev libopusfile-dev ffmpeg
