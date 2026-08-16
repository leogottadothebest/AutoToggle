# 软件物料清单（SBOM）

AutoToggle 2.1.0 分发的软件组件清单。

## 组件

| 组件 | 版本 | 许可证 | 来源 |
| --- | --- | --- | --- |
| AutoToggle（本应用） | 2.1.0 | MIT | <https://github.com/leogottadothebest/AutoToggle> |
| Sparkle（更新框架） | 2.9.5 | MIT | <https://github.com/sparkle-project/Sparkle>（SPM `binaryTarget`，钉版 `exactVersion`） |

## 说明

- 无其它第三方运行时依赖（除 Sparkle 外，应用无网络 SDK、无分析 SDK）。
- Sparkle 版本由 `project.yml` 的 `exactVersion` 钉住，`scripts/generate-appcast.sh` 从 `project.yml` 解析同一版本，避免漂移。
- 完整第三方许可证见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。

## 供应链加固状态

- ✅ 依赖钉版（Sparkle `exactVersion` + Renovate 自动追踪）
- ✅ 更新通道 EdDSA 签名（`appcast.xml`）
- ✅ Release 构建签名门禁（`verify-signing.sh`：Hardened Runtime / 无 get-task-allow / apple-events）
- ✅ Sparkle 私钥文件权限 `chmod 600`
- ⬜ 提交签名（需配置 GPG/SSH 签名密钥，见 CONTRIBUTING.md）
- ⬜ SLSA provenance（需在 CI 里加 attestation 生成）
