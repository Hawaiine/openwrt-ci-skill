#!/bin/bash
# ============================================================
# minisign 固件签名脚本
# 用法: bash scripts/minisign-sign.sh <sha256sums-file> [key-id]
# 环境变量: MINISIGN_SECRET_KEY, MINISIGN_KEY_ID, MINISIGN_PASSWORD
# ============================================================
set -euo pipefail

SHA_FILE="${1:-sha256sums}"
KEY_FILE="/tmp/minisign.key"

if [ ! -f "$SHA_FILE" ]; then
    echo "❌ 未找到 sha256sums: $SHA_FILE"
    exit 1
fi

# 写入密钥
if [ -z "${MINISIGN_SECRET_KEY:-}" ]; then
    echo "❌ MINISIGN_SECRET_KEY 未设置"
    exit 1
fi
echo "$MINISIGN_SECRET_KEY" > "$KEY_FILE"

# 构建签名命令
SIGN_CMD="minisign -Sm \"$SHA_FILE\" -s \"$KEY_FILE\""
[ -n "${MINISIGN_KEY_ID:-}" ]   && SIGN_CMD="$SIGN_CMD -W ${MINISIGN_KEY_ID}"
[ -n "${MINISIGN_PASSWORD:-}" ] && SIGN_CMD="MINISIGN_PASSWORD=\"${MINISIGN_PASSWORD}\" $SIGN_CMD"

eval "$SIGN_CMD"
rm -f "$KEY_FILE"

echo "✅ 签名完成: ${SHA_FILE}.minisig"