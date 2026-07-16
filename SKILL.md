---
name: openwrt-ci-skill
description: "OpenWrt 固件构建 CI/CD 最佳实践——从实战中提炼的多阶段流水线设计、缓存策略、首次启动状态机、验证纪律与提交规范。适用于任何 OpenWrt 固件编译项目。"
version: 1.1.0
author: Hermes Agent
platforms: [linux]
metadata:
  hermes:
    tags: [openwrt, ci-cd, github-actions, build-pipeline, firmware]
    related_skills: [systematic-debugging, plan, github-actions-workflows]
---

# OpenWrt CI Skill

从 [Oasisic OpenWrt](https://github.com/Hawaiine/oasisic-openwrt) 实战项目中提炼的 CI/CD 最佳实践。覆盖了从 Git 提交规范到多阶段流水线、从首次启动状态机到排错原则的完整知识体系。

---

## 一、项目结构规划

```
openwrt-firmware/
│
├── .github/workflows/
│   ├── main-build.yml           ← 多阶段流水线
│   └── cleanup.yml              ← 定时清理
├── files/                       ← 注入固件的自定义文件
│   ├── etc/config/              ← 默认配置（network / firewall / system / dhcp 等）
│   ├── etc/uci-defaults/        ← 首次启动脚本（99-custom）
│   ├── etc/banner               ← SSH 登录横幅
│   └── www/
│       ├── index.html           ← 入口检测页
│       ├── setup.html           ← 设置向导
│       └── cgi-bin/             ← CGI 后端
├── scripts/
│   ├── gen-config.sh            ← 包配置生成器
│   ├── gen-feeds-conf.sh        ← 动态 feeds 生成器
│   ├── check-firmware.sh        ← 固件自检
│   ├── minisign-sign.sh         ← 签名脚本
│   └── notify-discord.py        ← 通知脚本
├── feeds.conf                   ← 依赖源列表
├── .github/
│   └── minisign.pub             ← 签名公钥
├── last_build_version           ← 上次构建版本标识
└── README.md
```

> 💡 本 skill 的 `templates/` 目录包含上述所有脚本的可复用模板，详见 [Templates 说明](#十四模板文件)。
```

---

## 二、CI/CD 流水线设计

### 2.1 多阶段流水线

```
check-upstream → build → qemu-smoke-test → release → notify
```

### 2.2 关键规则

#### needs 依赖链（⚠️ 最容易出错）

```yaml
# 正确：下游 job 必须显式列出所有 outputs 来源
build:
  needs: check-upstream
  outputs:
    version: ${{ needs.check-upstream.outputs.version }}

qemu-smoke-test:
  needs: [check-upstream, build]    # ← 必须包含 check-upstream！

release:
  needs: [check-upstream, build, qemu-smoke-test]  # ← 必须包含 build！
```

**规则**：`needs.<job>.outputs` 只在你当前 job 的 `needs:` 列表中有该 job 时才可访问。即使上游 job 的 `outputs:` 声明了传递值，下游仍需显式依赖。

#### GitHub Secrets 注入

```yaml
- name: 🔏 签名
  env:
    SECRET_KEY: ${{ secrets.SECRET_KEY }}    # 必须显式 env 映射
  run: bash scripts/sign.sh
```

#### 三层缓存策略

| 层级 | 缓存内容 | Key 策略 |
|------|---------|----------|
| ccache | 编译对象缓存 | `ccache-{ver}-{config_hash}` |
| 源码树 | 完整源码 | `source-{ver}` |
| 下载包 | 依赖包 | `dl-{ver}-{config_hash}` |

#### 编译优化

```yaml
MAKE_JOBS: 4   # 免费 runner 2 核 4 线程，不写 $(nproc)
```

```bash
# 失败时自动 verbose 重跑
make -j$MAKE_JOBS || { make -j1 V=s; }

# bash 原生 retry
n=0
until [ $n -ge 3 ]; do
  make download && break
  n=$((n+1))
  sleep 30
done
```

---

## 三、配置管理

### 3.1 首次启动状态机

```
uci-defaults 创建 .firstboot 标记
  → 用户访问 → index.html 检测
  → 有标记 → 跳转 setup.html 设置向导
  → 用户完成 → CGI 写入配置 + 清标记 + chmod 000 自禁用
  → 下次访问 → 跳转 LuCI 管理界面
```

文件结构：
```
files/
├── usr/lib/oasisic/
│   └── firstboot.sh          ← 共享库（is_firstboot / require / clear）
├── etc/uci-defaults/
│   └── 99-custom              ← 创建标记 + 默认配置
└── www/
    ├── index.html             ← 入口检测页
    ├── setup.html             ← 设置向导页面
    └── cgi-bin/
        ├── check-firstboot    ← 检测 CGI
        └── setup              ← 配置写入 CGI
```

**关键规则**：
- 标记文件：`/etc/.oasisic-firstboot`
- CGI 接收 `skip` 参数，支持跳过模式
- CGI 完成后 `chmod 000` 自禁用
- 零外部依赖（无 CDN / 外部字体 / 图标库）

### 3.2 配置文件规则

- **不要 drop 完整配置文件**：`files/etc/config/luci` 等文件会覆盖系统默认，导致 LuCI 403/404
- 正确做法：用 `uci-defaults` 覆盖特定字段
- `uci-defaults` 脚本执行后自清理（`rm /etc/uci-defaults/99-custom`）

### 3.3 常见配置陷阱

| 陷阱 | 说明 |
|------|------|
| `hostname` 含空格 | `Oasisic OpenWrt` 无效，必须用 `Oasisic-OpenWrt` |
| Banner 硬编码 IP | 固件 DHCP 模式下 IP 由主路由分配，硬编码无效 |
| 缺少 `ucode` 包 | 有 `ucode-mod-*` 但没有 `ucode` → CGI 403 → LuCI 无限转圈 |
| `luci-compat` 残留 | 25.12 核心模块已迁移到 ucode/JSAPI，不需要 Lua 兼容层 |
| `luci-lua-runtime` 误删 | C 模块（如 `luci-bwc`）需要 `liblua.so`，必须保留 |

---

## 四、Feeds 管理

### 4.1 分支锁定

OpenWrt 25.12 使用 `;` 语法（非 `^`）：

```
src-git packages https://github.com/openwrt/packages.git;openwrt-25.12
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
```

### 4.2 Feed 名称规则

OpenWrt `scripts/feeds` 的 Perl 解析器用 `\w+` 验证 feed 名，**不支持连字符**。

### 4.3 版本追踪

`scripts/gen-feeds-conf.sh` 从版本 tag 推导分支名：
- `v25.12.5` → `openwrt-25.12`
- 使用 GitHub 镜像（国内连通性优于 `git.openwrt.org`）

---

## 五、包选择（gen-config.sh）

### 5.1 必选包

```
CONFIG_PACKAGE_ucode=y          # LuCI CGI 必选依赖
CONFIG_PACKAGE_luci-lua-runtime=y  # C 模块需要 liblua.so
```

### 5.2 安全移除项

```
# luci-compat：Lua 兼容层，25.12 核心模块已迁移到 ucode/JSAPI
# luci-theme-argon：改用 bootstrap
# luci-app-statistics：不需要
# luci-app-attendedsysupgrade：指向官方 ASU 服务器，不适合定制固件
```

### 5.3 版本提取

- **内核版本**：从 `include/kernel-version.mk` 提取 `KERNEL_PATCHVER`
- **Nikki 版本**：从 `luci-app-nikki` 包文件名提取（APK 或 IPK）

---

## 六、产物自检

### 6.1 双层验证框架

```
Tier 1：APK/IPK 完整性检查（信息级，不阻断）
  - 搜索 luci-base 包
  - 验证 resourcebase / ubuspath
  - JS 资源缺失标记为 WARN（25.12 可能分散在其他包）

Tier 2：固件 squashfs 提取检查（信息级）
  - fdisk + hsqs magic 双保险偏移检测
  - 验证固件内关键文件存在
```

### 6.2 关键设计

- `find` 替代 `ls glob`：避免 `set -euo pipefail` 下无匹配 exit 2
- APK 解压用 Python 双 gzip 流提取（控制流 + 数据流拼接）
- 始终 `exit 0`，不阻断构建

---

## 七、固件签名

### 7.1 minisign 签名

```bash
# 安装依赖
pip install pynacl -q

# 签名
bash scripts/minisign-sign.sh sha256sums

# 用户验证
sha256sum -c sha256sums
minisign -Vm sha256sums -P "$(cat .github/minisign.pub)"
```

### 7.2 CI 配置

```yaml
- name: 🔏 固件签名
  env:
    MINISIGN_SECRET_KEY: ${{ secrets.MINISIGN_SECRET_KEY }}
    MINISIGN_KEY_ID: ${{ secrets.MINISIGN_KEY_ID }}
    MINISIGN_PASSWORD: ${{ secrets.MINISIGN_PASSWORD }}
  run: |
    pip install pynacl -q
    bash scripts/minisign-sign.sh sha256sums
```

---

## 八、QEMU 烟雾测试

```yaml
qemu-smoke-test:
  needs: [check-upstream, build]
  timeout-minutes: 15
  steps:
    - uses: actions/download-artifact@v7
    - run: |
        # 安装 OVMF + QEMU
        sudo apt-get install -y qemu-system-x86-64 ovmf

        # find 查找固件（勿用 ls glob）
        FIRMWARE=$(find firmware/ -name '*-squashfs-combined-efi.img.gz' -type f | head -1)

        # UEFI 启动
        qemu-system-x86_64 -bios /usr/share/OVMF/OVMF_CODE_4M.fd ...

        # 轮询 LuCI HTTP 200（300s 超时）
        # 检测 kernel panic / Oops
```

---

## 九、工具包选择建议

| 包 | 用途 | 建议 |
|----|------|------|
| `bash` | Shell | ✅ 保留 |
| `curl` / `wget-ssl` | 网络请求 | ✅ 保留 |
| `htop` | 进程监控 | ✅ 保留 |
| `tcpdump` | 网络抓包 | ✅ 保留 |
| `vim` | 编辑器 | ✅ 保留（基础版够用，不用 `vim-full`） |
| `iperf3` | 网络测速 | ❌ 旁路网关不需要 |
| `lm-sensors` | 硬件传感器 | ❌ 旁路网关不需要 |

---

## 十、Git 提交规范

### 10.1 Commit 格式

```
<emoji> <简短标题>

<详细描述>
- 做了什么
- 为什么（官方依据 / 问题根因）
- 变更清单

官方依据：<文档链接 / 源码参考>
验证：bash -n ✓，diff 对比 ✓，功能合理 ✓
```

### 10.2 Emoji 前缀

| Emoji | 含义 |
|-------|------|
| ✨ | 新功能 |
| 🔧 | 配置变更 / 脚本 |
| 🐛 | Bug 修复 |
| ⚡ | 性能优化 |
| 🧹 | 清理 / 重构 |
| 🛡️ | 安全 |
| 📝 | 文档 |
| 🎨 | UI / 样式 |

### 10.3 推前纪律

1. 验证三遍：语法检查 → diff 对比 → 功能合理性
2. 官方资料优先，不凭猜测
3. 批量查找问题，不逐个修复

---

## 十一、已知陷阱一览

| 陷阱 | 现象 | 解决 |
|------|------|------|
| `needs` 链缺失 | 下游 job 取不到 outputs | `needs: [check-upstream, build, ...]` |
| Secrets 未 env 映射 | 脚本读不到密钥 | step 中加 `env:` 块 |
| `set -e` + `ls glob` | 无匹配时 exit 2 | 用 `find` 替代 |
| `make -j$(nproc)` | 超出 runner 核心 | 硬编码 `MAKE_JOBS: 4` |
| 缺少 `ucode` 包 | LuCI 无限转圈 | `CONFIG_PACKAGE_ucode=y` |
| Banner 硬编码 IP | DHCP 模式下 IP 由主路由分配 | 用官方 logo + `%V` `%H` |
| 标记文件忘清 | 每次启动进向导 | CGI 完成后清标记 + chmod 000 |
| Feed 名含连字符 | `scripts/feeds` 报 Syntax error | 用 `[a-zA-Z0-9_]` 命名 |
| `;` 和 `^` 混用 | 分支锁定失败 | 25.12 用 `;`，Nikki 用 `;main` |
| APK 用 `tar -xzf` | 只解压控制流，丢数据流 | Python 双 gzip 流提取 |
| `concurrency` group 同名 | main 和 PR 互相取消 | `${{ github.workflow }}-${{ github.ref }}` 区分 |
| Runner 磁盘打满 | `No space left on device` | build 前删 dotnet/ghc/boost/android |
| 缓存 key 跨分支污染 | 不同分支命中同一缓存 | 缓存 key 包含 `github.ref` 或 `github.sha` |

---

## 十二、排错原则

1. **官方资料优先**：不确定时查 openwrt.org / GitHub 官方仓库 / Alpine APK 规范
2. **看日志不看经验**：每次失败先看完整日志，不靠记忆推断
3. **批量扫描再修**：连续失败 2 次以上 → 全面扫描相关环节 → 一次性修复
4. **验证依赖链**：GitHub Actions 中 `needs` 链缺失是常见故障点

---

## 十三、模板文件（templates/）

本 skill 仓库的 `templates/` 目录包含可直接复用的脚本模板：

| 模板 | 用途 |
|------|------|
| `gen-config.sh` | 包配置生成器（x86/64，Nikki，PVE，ucode） |
| `gen-feeds-conf.sh` | 动态 feeds.conf 生成器（从 tag 推导分支） |
| `firstboot.sh` | 首次启动状态机共享库 |
| `99-custom` | uci-defaults 补丁（DHCP + IPv6 中继 + 创建标记） |
| `index.html` | 入口检测页（首次启动引导） |
| `cgi-bin/check-firstboot` | 首次启动检测 CGI |
| `cgi-bin/setup` | 配置写入 CGI（IPv4 校验 + 密码 + 自禁用） |
| `minisign-sign.sh` | 固件签名脚本 |
| `notify-discord.py` | Discord Embed 通知脚本 |
| `main-build.yml` | 完整 CI 流水线（4 站式） |
| `cleanup.yml` | 定时清理工作流 |

使用方式：

```bash
# 直接复制到你的项目中
cp templates/gen-config.sh your-project/scripts/
cp templates/main-build.yml your-project/.github/workflows/
# 根据需要修改品牌名、包选择等
sed -i 's/My OpenWrt/Your Brand/g' your-project/scripts/gen-config.sh
```