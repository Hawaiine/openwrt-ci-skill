---
name: openwrt-ci-skill
description: "OpenWrt 固件构建 CI/CD 最佳实践——从实战中提炼的多阶段流水线设计、缓存策略、首次启动状态机、验证纪律与提交规范。适用于任何 OpenWrt 固件编译项目。"
version: 1.2.0
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
│   ├── etc/config/              ← 默认配置（network / firewall / system / dhcp 等，无需完整 drop）
│   ├── etc/uci-defaults/        ← 首次启动脚本（99-custom）
│   ├── etc/banner               ← 可选自定义（无此文件则用 base-files 官方默认）
│   ├── etc/shadow               ← 随机密码模板
│   └── www/
│       ├── index.html           ← 入口检测页
│       ├── setup.html           ← 设置向导（含轮询确认逻辑）
│       └── cgi-bin/             ← CGI 后端（setup、check-firstboot、setup-rollback）
├── scripts/
│   ├── gen-config.sh            ← 包配置生成器
│   ├── gen-feeds-conf.sh        ← 动态 feeds 生成器
│   ├── check-firmware.sh        ← 固件自检（含 APK 迁移期检查）
│   ├── check-docs-consistency.sh ← 文档一致性校验
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

#### 文档一致性校验

编译阶段增加文档校验步骤，对比 README 中声称的功能包与 `gen-config.sh` 的实际配置：

```bash
# scripts/check-docs-consistency.sh
# 校验 README 关键词（如 Nikki、PVE、dnsmasq）对应 CONFIG_PACKAGE_*=y
# 校验 gen-config.sh 排除的包是否在 README 中说明
bash scripts/check-docs-consistency.sh
```

#### 构建产物自检

| 阶段 | 检查项 | 说明 |
|------|--------|------|
| build | 包完整性 | luci-base 包存在性、APK 格式一致性、APKINDEX 可解压 |
| build | 文档一致性 | README 声称 vs gen-config.sh 实际配置 |
| qemu | LuCI 可达性 | HTTP 200 + JS 资源完整性（非空 + 非 gzip 二进制） |

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
- 标记文件：`/etc/.firstboot-marker`
- CGI 接收 `skip` 参数，支持跳过模式
- CGI 完成后 `chmod 000` 自禁用
- 零外部依赖（无 CDN / 外部字体 / 图标库）

### 3.2 设置向导健壮性

#### 轮询确认（替代固定延时跳转）

CGI 写入配置后，前端不再使用 `setTimeout(xxxms)` 固定延时跳转，改为轮询新 IP：

```javascript
// setup.html —— 轮询新地址
var pollUrl = 'http://' + newIp + ':' + newPort + '/cgi-bin/luci';
var pollTimer = setInterval(function() {
  // ⚠️ 不要用 new Image() 探测！/cgi-bin/luci 返回 HTML 非图片，
  // 浏览器对非图片成功响应触发 onerror（而非 onload），必然假阴性。
  // 改用 fetch(no-cors)：网络层连通即 resolve，连不上才 reject。
  fetch(pollUrl, { mode: 'no-cors', cache: 'no-store' })
    .then(function() {
      clearInterval(pollTimer);
      window.location.href = pollUrl;
    })
    .catch(function() { /* 继续轮询 */ });
}, 3000);
// 60 秒超时 → 显示手动访问链接 + 回滚入口
```

#### 回滚保护

CGI 修改网络配置前保存原始状态，提供回滚入口：

```bash
# 保存原始配置
uci show network.lan > /tmp/.setup-original
uci show uhttpd.main > /tmp/.setup-original-uhttpd

# 回滚脚本（usr/lib/.../setup-rollback.sh）
# 读取保存的配置 → uci set → uci commit → network reload
```

提供 `cgi-bin/setup-rollback` 作为手动回滚入口。

**回滚链接必须是绝对地址（Bug #4 修复）：**
超时提示中的回滚链接不可用相对路径（如 `href="/cgi-bin/setup-rollback"`），因为此时设备的网络配置已切换到新 IP，旧地址在网卡上已不存在。必须使用绝对地址指向新地址：
```javascript
'<a href=\"http://' + newIp + ':' + newPort + '/cgi-bin/setup-rollback\">回滚页面</a>'
```
同时应如实告知用户：如果新地址也不可达（如网关/掩码设置错误导致设备完全离线），需通过物理串口或直连旧地址路由器手动干预。

#### 服务重启安全问题

CGI 作为 uhttpd 子进程运行时，直接 `uhttpd restart` 会触发 procd 整组 kill：

```bash
# ❌ 错误：仍在 uhttpd 进程组内
/etc/init.d/uhttpd restart &

# ✅ 正确：用 setsid 脱离进程组，sleep 2 给 CGI 留时间写响应
setsid sh -c 'sleep 2 && /etc/init.d/network reload && /etc/init.d/uhttpd restart' &
```

### 3.3 配置文件规则

- **不要 drop 完整配置文件**：`files/etc/config/luci` 等文件会覆盖系统默认，导致 LuCI 403/404
- **`resourcebase` 必须显式设置**：LuCI 登录页实际读取的是 `core 'main'` 段下的 `resourcebase`，而 `/etc/config/luci` 默认只有 `internal 'internals'` 段下的同名配置，两者不是一回事。缺少此字段 → `"resourcebase":null` → JS 资源请求到错误根路径 → 404 + "正在载入视图"卡死。
- 正确做法：用 `uci-defaults` 覆盖特定字段（`resourcebase`, `lang`, `mediaurlbase` 等）
- `uci-defaults` 脚本执行后自清理（`rm /etc/uci-defaults/99-custom`）

### 3.4 常见配置陷阱

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

- **内核版本**：从 `include/kernel-version.mk` 提取 `KERNEL_PATCHVER`，再从 `target/linux/generic/kernel-{PATCHVER}` 提取 `LINUX_VERSION` 后缀，拼接为完整版本（如 `6.12.94`）
- **Nikki 版本**：从 `luci-app-nikki` 包文件名提取（APK 或 IPK）

---

## 六、产物自检

### 6.1 双层验证框架

```
Tier 1：APK/IPK 完整性检查（信息级，不阻断）
  - 搜索 luci-base 包
  - 验证 resourcebase / ubuspath
  - APK 格式一致性检查（纯 .apk / 纯 .ipk，混用警告）
  - APKINDEX.tar.gz 存在且可解压（仓库数据库完整性）
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

        # 检查 JS 资源完整性（阻断门）
        for url in \
          "http://127.0.0.1:8080/luci-static/resources/luci.js" \
          "http://127.0.0.1:8080/luci-static/resources/ui.js"; do
          JS=$(curl -sL "$url")
          [ ${#JS} -lt 100 ] && { echo "❌ $url 内容过短"; exit 1; }

          # 检查非 gzip 二进制（od 配合 here-string 避免 SIGPIPE）
          BYTES=$(od -A n -t x1 <<< "${JS:0:20}" | tr -d ' ')
          echo "$BYTES" | grep -q '^1f8b' && { echo "❌ gzip 二进制"; exit 1; }
        done
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
| `resourcebase` 未设置 | `"resourcebase":null` → JS(404) → 页面卡死"正在载入视图" | 99-custom 中加 `uci set luci.main.resourcebase='/luci-static/resources'` |
|| Banner 硬编码 IP | DHCP 模式下 IP 由主路由分配 | 删除 banner 文件，使用 base-files 官方默认（`%D %V, %C ${codename}`） |
| 标记文件忘清 | 每次启动进向导 | CGI 完成后清标记 + chmod 000 |
| Feed 名含连字符 | `scripts/feeds` 报 Syntax error | 用 `[a-zA-Z0-9_]` 命名 |
| `;` 和 `^` 混用 | 分支锁定失败 | 25.12 用 `;`，Nikki 用 `;main` |
|| NTP `use_dhcp` 默认启用 | `portmap` NTP 配置未设定时 LuCI 默认勾选"使用 DHCP 通告的服务器" | 显式加 `option use_dhcp '0'` 到 `config timeserver 'ntp'`，关闭 DHCP 通告 |
| `concurrency` group 同名 | main 和 PR 互相取消 | `${{ github.workflow }}-${{ github.ref }}` 区分 |
| Runner 磁盘打满 | `No space left on device` | build 前删 dotnet/ghc/boost/android |
| 缓存 key 跨分支污染 | 不同分支命中同一缓存 | 缓存 key 包含 `github.ref` 或 `github.sha` |
| `printf \| head` 在 pipefail 下炸 | 大数据量 JS 检查时 `printf: Broken pipe` | 用 `od <<< "\${var:0:20}"` here-string 替代 `printf \| head` |
|| CGI 内重启父进程 uhttpd | procd 整组 kill 时子进程被误杀，响应未写完 | 用 `setsid sh -c 'sleep 2 && /etc/init.d/uhttpd restart' &` 脱离进程组 |
|| `luci-mod-admin-full` 子模块重复声明 | 同时声明 `luci-mod-admin-full` 和 `luci-mod-network/status/system` | `luci-mod-admin-full` 的 DEPENDS 已包含所有子模块，无需重复 |
|| `luci-light` 与 `luci` 同时选择 | 两个 meta 包功能重叠但依赖树不同，全量编译时可能导致 `cbi.js`/`luci.js` 缺失 | 只保留 `CONFIG_PACKAGE_luci=y`，删除 `luci-light` |
|| `show_menu` 非官方选项 | `uci set luci.title.show_menu='0'` 写入但无任何代码读取此值，是不可见的僵尸选项 | 直接删除，不影响 LuCI 菜单显隐 |
|| CGI 内 `passwd` 可用 | uhttpd 环境下 `printf | passwd` 能正常执行（实测通过） | `passwd` 在 uhttpd 子进程中有 stdin 管道，无需 tty |
|| shadow 文件含 `#` 注释行 | `passwd` 报 `no record of root`，密码写入 `/etc/passwd` | shadow 文件禁止任何 `#` 注释行，CI 中 `sed -i '/^#/d'` 防御性清理 |
|| CI 密码写入后无校验 | 密码写失败但构建成功，Release 无有效密码 | 写入后 `grep -q "^root:"` 校验，失败 `exit 1` |

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
| `99-custom` | uci-defaults 补丁（resourcebase/DHCP/IPv6 禁用 + 创建标记） |
| `index.html` | 入口检测页（首次启动引导） |
| `cgi-bin/check-firstboot` | 首次启动检测 CGI |
| `cgi-bin/setup` | 配置写入 CGI（jshn + openssl SHA-512 直接写 shadow，setsid 重启） |
| `cgi-bin/setup-rollback` | 手动回滚 CGI |
| `setup-rollback.sh` | 回滚脚本（从 /tmp/.setup-original 恢复） |
| `check-docs-consistency.sh` | 文档一致性校验（README vs gen-config.sh） |
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