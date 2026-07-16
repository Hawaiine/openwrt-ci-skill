#!/bin/bash
# ============================================================
# 生成 OpenWrt 全量 SDK 编译用的 .config 文件
# 用法: bash scripts/gen-config.sh <build-dir>
# ============================================================
set -e

BUILD_DIR="${1:-openwrt}"
CONFIG_FILE="${BUILD_DIR}/.config"

cat > "$CONFIG_FILE" << 'CONFIGEOF'
# ─── 目标平台 ──────────────────────────────────────────
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y

# ─── 镜像格式 ──────────────────────────────────────────
CONFIG_TARGET_ROOTFS_PARTSIZE=512
CONFIG_TARGET_KERNEL_PARTSIZE=32
CONFIG_GRUB_TIMEOUT="3"
CONFIG_GRUB_TITLE="My OpenWrt"
CONFIG_ISO_IMAGES=y
CONFIG_VMDK_IMAGES=n
CONFIG_GRUB_IMAGES=y
CONFIG_TARGET_IMAGES_GZIP=y

# ─── 语言 ──────────────────────────────────────────────
CONFIG_LUCI_LANG_zh_Hans=y

# ─── 语言包 ────────────────────────────────────────────
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y
CONFIG_PACKAGE_luci-i18n-filemanager-zh-cn=y
CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y

# ─── DNS ──────────────────────────────────────────────
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_dnsmasq_full_dhcp=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_dnsmasq_full_dnssec=y
CONFIG_PACKAGE_dnsmasq_full_nftset=y
CONFIG_PACKAGE_dnsmasq_full_auth=y
CONFIG_PACKAGE_dnsmasq_full_conntrack=y
CONFIG_PACKAGE_dnsmasq_full_tftp=y
CONFIG_PACKAGE_dnsmasq_full_noid=y

# ─── 防火墙 / 网络 ─────────────────────────────────────
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_nftables-json=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_yq=y
CONFIG_PACKAGE_cgi-io=y

# ─── IPv6 ─────────────────────────────────────────────
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_luci-proto-ipv6=y

# ─── Nikki 代理（从 feeds 编译） ─────────────────────────
CONFIG_PACKAGE_nikki=y
CONFIG_PACKAGE_mihomo-meta=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y
CONFIG_PACKAGE_kmod-nf-socket=y
CONFIG_PACKAGE_kmod-nf-tproxy=y
CONFIG_PACKAGE_kmod-nft-socket=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-dummy=y
CONFIG_PACKAGE_libbpf=y

# ─── PVE 集成 ───────────────────────────────────────────
CONFIG_PACKAGE_qemu-ga=y
CONFIG_PACKAGE_kmod-virtio-serial=y
CONFIG_PACKAGE_kmod-virtio-net=y
CONFIG_PACKAGE_kmod-virtio-blk=y
CONFIG_PACKAGE_kmod-virtio-scsi=y
CONFIG_PACKAGE_kmod-virtio-rng=y

# ─── LuCI 核心 ─────────────────────────────────────────
CONFIG_PACKAGE_luci-light=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-proto-ipv6=y
CONFIG_PACKAGE_luci-lua-runtime=y    # C 模块需要 liblua.so
CONFIG_PACKAGE_ucode=y               # LuCI CGI 必选依赖（⚠️ 缺少则 LuCI 无限转圈）
CONFIG_PACKAGE_ucode-mod-json=y

# ─── 常用工具 ──────────────────────────────────────────
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_vim=y
CONFIG_PACKAGE_coreutils-base64=y
CONFIG_PACKAGE_coreutils-nohup=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_tmux=y
CONFIG_PACKAGE_openssh-sftp-server=y

# ─── 不包含 ────────────────────────────────────────────
# CONFIG_PACKAGE_luci-compat=         # Lua 兼容层（25.12 不需要）
# CONFIG_PACKAGE_luci-theme-argon=    # 改用 bootstrap
# CONFIG_PACKAGE_luci-app-statistics= # 不需要
# CONFIG_PACKAGE_luci-app-attendedsysupgrade=  # 指向官方 ASU，不适合定制固件
# CONFIG_PACKAGE_iperf3=              # 旁路网关不需要
# CONFIG_PACKAGE_lm-sensors=          # 旁路网关不需要
# CONFIG_PACKAGE_vim-full=            # vim 就够了
CONFIGEOF

echo "✅ .config 已生成: $CONFIG_FILE ($(wc -c < "$CONFIG_FILE") bytes)"