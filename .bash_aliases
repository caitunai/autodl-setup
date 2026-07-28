alias proxy="export https_proxy=http://127.0.0.1:7897; http_proxy=http://127.0.0.1:7897; all_proxy=socks5://127.0.0.1:7897; echo 'Proxy On'"
alias unproxy="unset http_proxy https_proxy all_proxy; echo 'Proxy Off'"
alias supervisorctl="/root/.venv/bin/supervisorctl -c /etc/supervisor/supervisord.conf"
