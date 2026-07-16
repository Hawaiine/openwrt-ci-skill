#!/usr/bin/env python3
"""Discord 固件发布通知脚本（Embed 卡片）"""
import os
import sys
import json
import urllib.request

DISCORD_TOKEN = os.environ.get("DISCORD_TOKEN", "")
OWRT_VER      = os.environ.get("OWRT_VER", "?")
NIKKI_VER     = os.environ.get("NIKKI_VER", "?")
KERNEL_VER    = os.environ.get("KERNEL_VER", "?")
ROOT_PASS     = os.environ.get("ROOT_PASS", "?")
TAG           = os.environ.get("TAG", "?")
RELEASE_URL   = os.environ.get("RELEASE_URL", "?")
BUILD_TIME    = os.environ.get("BUILD_TIME", "?")

if not DISCORD_TOKEN:
    print("❌ DISCORD_TOKEN 未设置")
    sys.exit(1)

EMBED = {
    "embeds": [{
        "title": "🏝️ Oasisic OpenWrt 自动构建",
        "color": 0x00b4ff,
        "fields": [
            {"name": "OpenWrt", "value": OWRT_VER, "inline": True},
            {"name": "Nikki",   "value": NIKKI_VER, "inline": True},
        ],
        "description": (
            f"**编译完成，已发布**\n"
            f"[🔗 下载]({RELEASE_URL})\n\n"
            f"**登录信息**\n"
            f"用户名: `root`\n"
            f"密码: `{ROOT_PASS}`\n\n"
            f"**系统信息**\n"
            f"架构: x86/64\n"
            f"时间: {BUILD_TIME}"
        ),
        "footer": {"text": "Oasisic OpenWrt CI"},
        "timestamp": BUILD_TIME,
    }]
}

data = json.dumps(EMBED).encode("utf-8")
headers = {
    "Authorization": f"Bot {DISCORD_TOKEN}",
    "Content-Type": "application/json",
    "User-Agent": "Oasisic-CI/1.0",
}
req = urllib.request.Request(
    f"https://discord.com/api/v10/channels/{os.environ.get('CHANNEL_ID', '')}/messages",
    data=data, headers=headers, method="POST",
)

try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        print(f"✅ Discord 通知已发送 (HTTP {resp.status})")
except urllib.error.HTTPError as e:
    print(f"❌ Discord 通知失败: HTTP {e.code}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Discord 通知失败: {e}")
    sys.exit(1)