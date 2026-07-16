# 🏗️ OpenWrt CI Skill

> OpenWrt 固件构建 CI/CD 最佳实践 —— 从实战中提炼的知识体系

从 [Oasisic OpenWrt](https://github.com/Hawaiine/oasisic-openwrt) 项目（26 commits 重构、4 阶段流水线、全自动发布）中提炼的可复用经验。

---

## 📋 项目简介

这是一个 **纯 skill 文档项目**，不是可运行的代码模板。目标是让任何 agent 或开发者拿来就能上手搭建 OpenWrt 固件 CI/CD 项目。

## 📖 内容

| 章节 | 内容 |
|------|------|
| 一、项目结构 | 推荐目录布局 |
| 二、CI/CD 流水线 | 多阶段设计、needs 链、Secrets 注入、缓存、编译优化 |
| 三、配置管理 | 首次启动状态机、配置文件规则、常见陷阱 |
| 四、Feeds 管理 | 分支锁定、名称规则、版本追踪 |
| 五、包选择 | 必选包、安全移除项、版本提取 |
| 六、产物自检 | 双层验证、APK 双流提取 |
| 七、固件签名 | minisign 配置 |
| 八、QEMU 烟雾测试 | UEFI 启动、LuCI 探测 |
| 九、工具包选择 | 什么该留、什么该删 |
| 十、Git 提交规范 | 格式、emoji、推前纪律 |
| 十一、已知陷阱 | 10+ 个常见坑及解法 |
| 十二、排错原则 | 方法论 |

## 🚀 使用方式

1. 阅读 `SKILL.md` 了解完整知识体系
2. 新建 OpenWrt 固件项目时参考各章节
3. 将 `SKILL.md` 作为 skill 加载到 agent 中

## 📜 许可证

[MIT](LICENSE)