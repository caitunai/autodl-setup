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
    uv venv ~/.venv --prompt `whoami`
    
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

cp ./.secrets ~/.secrets
# ==========================================
# 第二部分：复制配置并避免重复添加到 .bashrc
# ==========================================
# 检查 .bashrc 中是否已经包含引入命令
SECRETSRC_CMD=". $HOME/.secrets"
if ! grep -Fq "$SECRETSRC_CMD" ~/.bashrc; then
    echo "$SECRETSRC_CMD" >> ~/.bashrc
    echo "已将 .secrets 引入代码追加到 ~/.bashrc"
else
    echo ".secrets 已存在于 ~/.bashrc 中，跳过追加。"
fi

. $HOME/.bashrc

apt-get update
apt-get -y install pkg-config libopus-dev libopusfile-dev ffmpeg gnupg2 ca-certificates lsb-release ubuntu-keyring
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
https://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | tee /etc/apt/preferences.d/99nginx
apt-get update
apt-get -y install nginx
apt-get clean
uv pip install httpx[socks] supervisor
./install_onnxruntime_gpu.sh
