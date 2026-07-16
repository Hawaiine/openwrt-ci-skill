#!/bin/bash
# =============================================================
# 产物完整性自检脚本（模板）
# 双层验证：依赖检查（信息级）+ 产物解压检查（信息级）
# 所有检查均为信息级，不阻断构建
# 用法: bash scripts/check-output.sh <build-dir>
# =============================================================
set -e

BUILD_DIR="${1:-build}"
TARGET_DIR="${BUILD_DIR}/output"
PKG_DIR="${BUILD_DIR}/packages"

PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1"
    local mode="${3:-fail}"
    if [ "$2" -eq 0 ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    elif [ "$mode" = "warn" ]; then
        echo "  ⚠️  $desc"
        WARN=$((WARN + 1))
    else
        echo "  ❌ $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "═══════════════════════════════════════════"
echo "  产物完整性自检"
echo "═══════════════════════════════════════════"
echo ""

# ─── Tier 1: 关键文件检查（信息级）────────────────
echo "◆ Tier 1: 关键文件检查（信息级）"

# find 替代 ls glob（避免 set -euo pipefail 下 exit 2）
CORE_ARTIFACT=$(find "${TARGET_DIR}" -name "*.img.gz" -o -name "*.tar.gz" -o -name "*.zip" 2>/dev/null | head -1)
check "核心产物存在" $([ -n "$CORE_ARTIFACT" ]; echo $?)

MANIFEST=$(find "${TARGET_DIR}" -name "*.manifest" -o -name "sha256sums" 2>/dev/null | head -1)
check "校验文件存在" $([ -n "$MANIFEST" ]; echo $?)

echo ""

# ─── Tier 2: 产物内容检查（信息级）───
echo "◆ Tier 2: 产物内容检查（信息级）"

if [ -f "$CORE_ARTIFACT" ]; then
    echo "  📦 产物: $(basename "$CORE_ARTIFACT") ($(du -h "$CORE_ARTIFACT" | cut -f1))"
    # 在这里添加自定义检查逻辑
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  结果: $PASS ✅  /  $FAIL ❌  /  $WARN ⚠️"
echo "═══════════════════════════════════════════"

# 所有检查均为信息级，不阻断构建
echo "ℹ️  所有检查均为信息级，不阻断构建"
exit 0