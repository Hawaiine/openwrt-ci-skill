# 🏗️ Auto Pipeline Template

> 通用型 GitHub CI/CD 项目模板 — 自动检测上游 → 编译构建 → 烟雾测试 → 发布 Release

[![build](https://github.com/<user>/<repo>/actions/workflows/main-build.yml/badge.svg)](https://github.com/<user>/<repo>/actions/workflows/main-build.yml)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

---

## 📋 项目简介

**Auto Pipeline Template** 是一套通用的自动化构建项目模板，从真实项目中提炼的最佳实践。当你需要在 GitHub 上搭建一个完整的 CI/CD 流水线时，可以用此模板快速起步。

### 适用场景

| 场景 | 说明 |
|------|------|
| 📦 自动编译 | 固件、工具链、二进制包等需要定期编译的项目 |
| 🔄 上游追踪 | 依赖上游项目版本，检测到更新后自动构建 |
| 🧪 质量门禁 | 编译后自动烟雾测试，通过后才发布 |
| 🔏 签名发布 | 产物签名、Release 自动发布、多渠道通知 |
| 🖥️ 首次配置 | 需要首次启动向导的嵌入式系统 |

---

## ✨ 特性一览

| 类别 | 特性 | 说明 |
|------|------|------|
| 🏗️ **流水线** | 4 阶段 | 检测 → 构建 → 烟雾测试 → 发布 |
| 💾 **缓存** | 3 层 | ccache + 源码树 + 下载包 |
| 🔄 **自动重试** | 3 次 | git clone / make download |
| 🧪 **烟雾测试** | 阻断门 | 编译通过后自动验证 |
| 🔏 **签名** | 可选 | 产物签名 + 公钥验证 |
| 🧹 **自动清理** | 每 3 天 | 删除失败运行 + 过期缓存 |
| 🖥️ **首次启动** | 向导 | 标记文件 + CGI 状态机 |
| 📋 **自检** | 信息级 | 双层验证，不阻断构建 |

---

## 🏗️ 构建流程

```
check-upstream
  │
  ├── ⏭️ 版本无变化 → 跳过
  │
  └── ✅ 检测到更新 → build
        │
        ├── 💾 释放磁盘空间
        ├── 📦 安装依赖
        ├── 💾 恢复缓存（ccache + 源码树 + dl）
        ├── ⬇️ 克隆源码（自动重试）
        ├── ⚙️ 配置生成
        ├── ⬇️ 下载依赖（自动重试）
        ├── 🏗️ 编译（失败时 verbose 重跑）
        ├── 🔏 签名（可选）
        ├── 📋 产物自检
        └── 📤 上传产物
              │
              ▼
        smoke-test（阻断门）
              │
              ├── ❌ 失败 → 终止
              │
              └── ✅ 通过 → release
                    │
                    ├── 🚀 发布 Release
                    └── 📢 通知
```

---

## 📂 项目结构

```
auto-pipeline-template/
│
├── .github/workflows/
│   ├── main-build.yml          ← 4 阶段流水线
│   └── cleanup.yml             ← 定时清理
│
├── files/                      ← 注入产物的自定义文件
│   ├── etc/
│   │   ├── config/             ← 默认配置
│   │   └── uci-defaults/       ← 首次启动脚本（99-custom）
│   ├── usr/lib/app-name/
│   │   └── firstboot.sh        ← 首次启动状态机
│   └── www/
│       ├── index.html          ← 入口检测页
│       └── cgi-bin/
│           └── check-firstboot ← 检测 CGI
│
├── scripts/
│   ├── gen-config.sh           ← 配置生成器
│   ├── check-output.sh         ← 产物完整性自检
│   └── notify.py               ← 通知脚本（Discord 等）
│
├── SKILL.md                    ← 可复用 skill
├── README.md                   ← 本文档
└── .gitignore
```

---

## 🚀 快速开始

### 1️⃣ 使用此模板

```bash
git clone https://github.com/<user>/auto-pipeline-template.git my-project
cd my-project
rm -rf .git
git init
git checkout -b main
git add -A
git commit -m "🎉 从模板初始化项目"
```

### 2️⃣ 替换占位符

搜索 `<org>`, `<repo>`, `<user>` 等占位符并替换为实际值。

### 3️⃣ 配置 GitHub Secrets

| Secret | 用途 | 必填 |
|--------|------|------|
| `NOTIFY_TOKEN` | 通知机器人 Token | 选填 |
| `SIGN_KEY` | 产物签名密钥 | 选填 |

### 4️⃣ 推送触发构建

```bash
git remote add origin https://github.com/<user>/my-project.git
git push -u origin main
```

GitHub Actions 每天北京时间 14:00 自动检测上游。也可在 Actions 页面手动触发。

---

## ⚙️ 自定义指南

### 修改配置生成器

编辑 `scripts/gen-config.sh`，按项目需求添加 `CONFIG_*` 选项。

### 修改自检逻辑

编辑 `scripts/check-output.sh`，在 Tier 1 / Tier 2 中添加自定义检查项。

### 修改通知方式

编辑 `scripts/notify.py`，适配 Discord / 企业微信 / 钉钉等平台。

### 添加首次启动向导

在 `files/www/` 下添加 `setup.html`，参考 `check-firstboot` CGI 的模式。

---

## 🛡️ 安全机制

| 维度 | 措施 |
|------|------|
| 🔑 密钥 | GitHub Secrets + 显式 env 映射 |
| 🧬 源码 | 仅官方源，无第三方未经验证源 |
| 🧹 自清理 | 首次启动脚本执行后自毁 |
| 🚫 零外部依赖 | CGI/页面无 CDN/外部字体/图标 |
| 🔏 签名验证 | 产物可选 minisign 签名 + 公钥验证 |
| 🧪 阻断门 | 烟雾测试未通过不发布 |

---

## 🔧 排错指南

### 常见问题

| 症状 | 原因 | 解决 |
|------|------|------|
| 下游 job 取不到 outputs | needs 链缺上游 job | `needs: [check-upstream, build]` |
| 脚本读不到密钥 | secrets 未 env 映射 | step 中添加 `env:` 块 |
| 构建直出失败 | 缺少依赖 | 检查 `apt-get install` 列表 |
| 缓存不命中 | key 设计问题 | 用版本 hash 代替 run_id |

---

## 📜 许可证

[MIT](LICENSE) — 自由使用，欢迎贡献。

---

> 🏗️ **Auto Pipeline Template** — 从实战中来，到实战中去