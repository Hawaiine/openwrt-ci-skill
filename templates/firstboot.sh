#!/bin/sh
# ============================================================
# 首次启动状态机共享库
# 被 /www/cgi-bin/* 脚本 source 加载
# ============================================================

FIRSTBOOT_MARKER="/etc/.oasisic-firstboot"

# 检查是否首次启动（标记文件是否存在）
oasisic_is_firstboot() {
    [ -f "$FIRSTBOOT_MARKER" ]
}

# 非首次启动时直接返回错误 JSON 并 exit 0
# 用法: oasisic_require_firstboot_or_exit
oasisic_require_firstboot_or_exit() {
    if ! oasisic_is_firstboot; then
        echo '{"success":false,"error":"设置向导已完成，此接口已禁用"}'
        exit 0
    fi
}

# 清除首次启动标记，可选自禁用调用脚本
# 用法: oasisic_clear_firstboot [/path/to/self]
oasisic_clear_firstboot() {
    rm -f "$FIRSTBOOT_MARKER"
    if [ -n "${1:-}" ] && [ -f "$1" ]; then
        chmod 000 "$1" 2>/dev/null || true
    fi
}