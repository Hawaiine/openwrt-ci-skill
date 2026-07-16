#!/bin/bash
# ============================================================
# 从 OpenWrt tag 推导分支名，动态生成 feeds.conf.default
# 用法: bash scripts/gen-feeds-conf.sh <owrt-tag> [nikki-tag]
# ============================================================
set -euo pipefail

OWRT_TAG="${1:-v25.12.5}"
NIKKI_TAG="${2}"

# 从 tag 推导 stable 分支名: v25.12.5 → openwrt-25.12
OWRT_BRANCH="openwrt-$(echo "${OWRT_TAG#v}" | cut -d. -f1-2)"

cat << FEOF
# OpenWrt feeds (GitHub 镜像, 分支: ${OWRT_BRANCH})
src-git packages https://github.com/openwrt/packages.git;${OWRT_BRANCH}
src-git luci https://github.com/openwrt/luci.git;${OWRT_BRANCH}
src-git routing https://github.com/openwrt/routing.git;${OWRT_BRANCH}
src-git telephony https://github.com/openwrt/telephony.git;${OWRT_BRANCH}
src-git video https://github.com/openwrt/video.git;${OWRT_BRANCH}
FEOF

# Nikki feed：使用 release tag 或 main 分支
if [ -n "$NIKKI_TAG" ]; then
    echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;${NIKKI_TAG}"
else
    echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main"
fi