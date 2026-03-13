#!/bin/sh

# =========================
# XrayR 一键安装 + OpenRC(supervise-daemon) 新方案
# Alpine 适用
# =========================

XRAYR_VER="v0.9.5"
XRAYR_ZIP="XrayR-linux-64.zip"
XRAYR_URL="https://github.com/put-go/XrayR/releases/download/${XRAYR_VER}/${XRAYR_ZIP}"

# 1) 更新并安装依赖
apk update
apk add wget unzip openrc

# 2) 准备目录
mkdir -p /etc/XrayR
mkdir -p /var/log

# 3) 下载并解压
cd /tmp || exit 1
wget -O "${XRAYR_ZIP}" "${XRAYR_URL}"
unzip -o "${XRAYR_ZIP}" -d /etc/XrayR

# 4) 设置执行权限 + 软链接
chmod +x /etc/XrayR/XrayR
ln -sf /etc/XrayR/XrayR /usr/bin/XrayR

# 5) 若配置不存在，给出提示（不强制覆盖）
if [ ! -f /etc/XrayR/config.yml ]; then
  echo "警告: /etc/XrayR/config.yml 不存在，请自行上传或配置后再启动。"
fi

# 6) 创建 OpenRC 服务（supervise-daemon 方案）
cat > /etc/init.d/XrayR << 'EOF'
#!/sbin/openrc-run
supervisor=supervise-daemon
name="XrayR"
description="XrayR Service"
command=/usr/bin/XrayR
command_args="-c /etc/XrayR/config.yml"
directory="/etc/XrayR"
supervise_daemon_args="--stdout /var/log/XrayR.log --stderr /var/log/XrayR.err --respawn-delay 2 --respawn-max 5 --respawn-period 1800"

depend() {
    need net
    after firewall
}

start_pre() {
    if [ ! -x /usr/bin/XrayR ]; then
        eerror "XrayR binary not found or not executable: /usr/bin/XrayR"
        return 1
    fi

    if [ ! -f /etc/XrayR/config.yml ]; then
        eerror "Config file not found: /etc/XrayR/config.yml"
        return 1
    fi

    touch /var/log/XrayR.log /var/log/XrayR.err
    return 0
}
EOF

chmod +x /etc/init.d/XrayR

# 7) 设置开机自启
rc-update add XrayR default

# 8) 启动服务（配置存在才启动）
if [ -f /etc/XrayR/config.yml ]; then
  rc-service XrayR restart
  if [ $? -ne 0 ]; then
    rc-service XrayR start
  fi
  rc-service XrayR status
else
  echo "未启动 XrayR：缺少 /etc/XrayR/config.yml"
fi

echo "安装完成！"
echo "管理命令:"
echo "  rc-service XrayR start|stop|restart|status"
echo "  rc-update add XrayR default"
echo "日志:"
echo "  /var/log/XrayR.log"
echo "  /var/log/XrayR.err"
