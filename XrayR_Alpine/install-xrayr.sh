#!/bin/sh
# 更新软件源
apk update
# 安装依赖项
apk add wget unzip openrc
# 下载 XrayR
wget https://github.com/put-go/XrayR/releases/download/v0.9.5/XrayR-linux-64.zip
# 解压缩
unzip XrayR-linux-64.zip -d /etc/XrayR
# 添加执行权限
chmod +x /etc/XrayR/XrayR
# 创建软链接
ln -s /etc/XrayR/XrayR /usr/bin/XrayR
# 创建 XrayR 服务文件
cat > /etc/init.d/XrayR << 'EOF'
#!/sbin/openrc-run

name="XrayR"
description="XrayR proxy service"
command="/usr/bin/XrayR"
command_args="-c /etc/XrayR/config.yml"
command_background="yes"
pidfile="/var/run/XrayR.pid"

# 关键：让 start-stop-daemon 创建 PID 文件
start_stop_daemon_args="--make-pidfile"

retry="TERM/30/KILL/5"

output_log="/var/log/XrayR/output.log"
error_log="/var/log/XrayR/error.log"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0755 /var/log/XrayR
    
    if [ ! -f /etc/XrayR/config.yml ]; then
        eerror "Config file not found: /etc/XrayR/config.yml"
        return 1
    fi
    
    if [ ! -x /usr/bin/XrayR ]; then
        eerror "XrayR binary not found or not executable: /usr/bin/XrayR"
        return 1
    fi
    
    # 清理可能存在的旧 PID 文件
    if [ -f "${pidfile}" ]; then
        local old_pid=$(cat "${pidfile}" 2>/dev/null)
        if [ -n "${old_pid}" ] && ! kill -0 "${old_pid}" 2>/dev/null; then
            rm -f "${pidfile}"
        fi
    fi
}

start_post() {
    sleep 2
    if [ -f "${pidfile}" ]; then
        local pid=$(cat "${pidfile}")
        if kill -0 "${pid}" 2>/dev/null; then
            einfo "XrayR started successfully with PID: ${pid}"
            return 0
        else
            eerror "XrayR process not running despite PID file exists"
            rm -f "${pidfile}"
            return 1
        fi
    else
        eerror "PID file was not created"
        return 1
    fi
}

stop_post() {
    # 强制清理 PID 文件
    if [ -f "${pidfile}" ]; then
        rm -f "${pidfile}"
    fi
    
    # 确保进程真的停止了
    if pgrep -f "/usr/bin/XrayR.*config.yml" >/dev/null 2>&1; then
        ewarn "XrayR process still running, force killing..."
        pkill -9 -f "/usr/bin/XrayR.*config.yml"
        sleep 1
    fi
    
    return 0
}
EOF


# 添加执行权限
chmod +x /etc/init.d/XrayR

# 添加到开机启动项中
rc-update add XrayR default

echo "安装完成！"
