#!/bin/sh
# firstboot.sh — 首次启动状态机
# 状态文件路径: /etc/.app-firstboot
# 使用方法: source /usr/lib/app-name/firstboot.sh

APP_FIRSTBOOT_FILE="/etc/.app-firstboot"

app_is_firstboot() {
    [ -f "$APP_FIRSTBOOT_FILE" ]
}

app_require_firstboot_or_exit() {
    if ! app_is_firstboot; then
        echo '{"success":false,"error":"已完成初始化，此接口已禁用"}'
        exit 0
    fi
}

app_clear_firstboot() {
    rm -f "$APP_FIRSTBOOT_FILE"
    if [ -n "${1:-}" ] && [ -f "$1" ]; then
        chmod 000 "$1" 2>/dev/null || true
    fi
}