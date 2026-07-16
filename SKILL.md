---
name: openwrt-build-template
description: "OpenWrt 固件构建 CI/CD 项目模板——从零搭建自动化编译/测试/发布流水线。包含多阶段 CI、烟雾测试、产物自检、配置注入、首次启动状态机等完整模式。"
version: 1.0.0
author: Hermes Agent
platforms: [linux]
metadata:
  hermes:
    tags: [ci-cd, github, automation, scaffolding, template, build-pipeline]
    related_skills: [systematic-debugging, plan, github-actions-workflows, new-project-scaffold]
---

# OpenWrt Build Template

从 OpenWrt 固件编译项目中提炼的 CI/CD 模板。适用于自动编译、工具链构建、固件发布等需要在 GitHub 上搭建完整流水线的场景。

---

## 项目结构

```
├── .github/workflows/
│   ├── main-build.yml          ← 4 阶段流水线（check → build → smoke → release）
│   └── cleanup.yml             ← 定时清理（失败运行 + 过期缓存）
├── files/                      ← 注入产物的自定义文件模板
│   ├── etc/config/             ← 默认配置文件
│   ├── etc/uci-defaults/       ← 首次启动脚本
│   ├── usr/lib/app-name/       ← 共享库
│   └── www/
│       ├── index.html          ← 入口检测页
│       └── cgi-bin/            ← CGI 接口
├── scripts/
│   ├── gen-config.sh           ← 配置生成器
│   ├── check-output.sh         ← 产物完整性自检
│   └── notify.py               ← 通知脚本
├── README.md
└── .gitignore
```

---

## 核心模式

### 1. 多阶段 CI/CD 流水线

```
check-upstream → build → smoke-test → release
```

**关键规则**：
- `needs:` 必须显式列出所有 outputs 来源 job（详见下方陷阱）
- Secrets 必须 `env:` 映射，不会自动注入到脚本环境
- 下载/克隆用 bash 原生 retry，不依赖第三方 action

### 2. 三层缓存策略

| 层级 | 缓存内容 | Key 策略 |
|------|---------|----------|
| ccache | 编译对象缓存 | `ccache-{ver}-{config_hash}` |
| 源码树 | 完整源码 | `source-{ver}` |
| 下载包 | 依赖包 | `dl-{ver}-{config_hash}` |

### 3. 首次启动状态机

```
uci-defaults 创建标记
  → 访问入口 → index.html 检测
  → 有标记 → 跳转设置向导
  → 用户完成 → CGI 写入 + 清标记 + 自禁用
  → 下次访问 → 跳转管理界面
```

### 4. 产物自检（非阻断）

- Tier 1：关键文件存在性检查
- Tier 2：产物内容解压检查
- 全部 `exit 0`，不阻断构建
- 使用 `find` 替代 `ls glob`

---

## 已知陷阱

| 陷阱 | 现象 | 解决 |
|------|------|------|
| needs 链缺失 | 下游 job outputs 为空 | `needs: [check-upstream, build]` |
| Secrets 未 env 映射 | 脚本读不到密钥 | step 中加 `env:` 块 |
| `set -e` + `ls glob` | 无匹配文件时 exit 2 | 用 `find` 替代 |
| `make -j$(nproc)` | 超出 runner 核心 | 硬编码 `MAKE_JOBS: 2` |
| 标记文件忘清 | 每次启动进向导 | CGI 完成后清标记 + chmod 000 |

---

## 使用方式

1. Fork 或 clone 此仓库
2. 替换 `<org>` / `<repo>` 占位符
3. 按需求修改 `gen-config.sh` 和 `check-output.sh`
4. 配置 GitHub Secrets
5. push 到 main → 自动触发构建