# 安全策略（Security Policy）

## 支持的版本

| 版本 | 支持状态 |
| --- | --- |
| 1.3.0（离线稳定线） | ✅ 支持（含安全修复） |
| 2.0.0 及以上（自动更新线） | ✅ 支持（见 `main` 分支） |
| 1.2.0 及更早 | ❌ 不再提供安全修复 |

## 范围

以下内容在安全策略覆盖范围内：

- AutoToggle 应用二进制（含代码签名与 Hardened Runtime 配置）
- Profile 配置文件的导入解析器
- 辅助功能 / Apple Events 权限的使用

> 注：1.x 离线线不含 Sparkle 自动更新链路（`appcast.xml` / EdDSA 签名），那是 2.x 线的范围。

## 报告漏洞

**请勿通过公开 Issue 报告安全漏洞。**

请使用 GitHub 的私密安全通告渠道：

1. 打开 [Security → Advisories](https://github.com/leogottadothebest/AutoToggle/security/advisories/new)
2. 描述漏洞、影响范围与复现步骤

我们会在确认后尽快修复，并遵循负责任的披露流程。修复完成后会在 CHANGELOG 的 `Security` 小节公开记录。
