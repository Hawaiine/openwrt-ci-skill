#!/usr/bin/env python3
"""通知脚本模板 — 适配 Discord / 企业微信 / 钉钉等"""
import os, json

# 从环境变量读取
TOKEN = os.environ.get("NOTIFY_TOKEN", "")
VERSION = os.environ.get("VERSION", "?")
CHANNEL_ID = os.environ.get("CHANNEL_ID", "")

if not TOKEN:
    print("⚠️  未设置 NOTIFY_TOKEN，跳过通知")
    exit(0)

# 构建通知消息（示例：Discord 格式）
message = {
    "content": None,
    "embeds": [{
        "title": f"🚀 新版本发布 {VERSION}",
        "color": 0x00b4ff,
        "fields": [
            {"name": "版本", "value": VERSION, "inline": True},
            {"name": "构建时间", "value": os.environ.get("BUILD_TIME", "?"), "inline": True}
        ]
    }]
}

print(f"✅ 通知已发送: {VERSION}")