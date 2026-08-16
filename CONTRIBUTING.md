# 贡献指南（Contributing）

感谢你对 AutoToggle 的关注！欢迎提交 Issue 和 Pull Request。

## 开发环境搭建

```bash
# 安装依赖
brew install xcodegen        # 工程生成器（project.yml 是唯一事实源）
brew install mint            # 钉版 Swift 工具（可选）

# 生成稳定的自签名签名证书（保证辅助功能授权在每次重建后不失效）
scripts/bootstrap-signing.sh

# 生成 Xcode 工程
xcodegen generate

# 构建 Release
scripts/build.sh
```

也可用 Makefile 快捷入口：`make help` 查看全部（`make build` / `make test` / `make lint`）。

## 仓库结构

- **私有开发仓库** `AutoToggle-developer`：日常开发与提交。
- **公开分发仓库** `AutoToggle`：开源源码 + `appcast.xml` + GitHub Release 的 DMG。

日常改动提交到私有仓库；公开发布时经 `SYNC.md` 流程同步到公开仓库。

## 提交前检查清单

- [ ] `project.yml` 仍是唯一事实源（未手改 `.pbxproj`）
- [ ] `README.md` 与 `README.zh-CN.md` 保持双语同步
- [ ] `CHANGELOG.md` 与 `CHANGELOG.zh-CN.md` 保持双语同步
- [ ] `make test` 全部通过
- [ ] 新增 UI 文案已在 `Localizable.xcstrings` 补齐中英双语

## 代码风格

- 遵循 `.swiftlint.yml` 与 `.swiftformat`（`make lint` / `make format`）
- 业务逻辑放在 `Managers/`，纯逻辑抽成可单测的纯类型（参见 `IdleDecisionEngine` / `ScheduleEngine`）

## 提交签名（推荐）

- 配置 GPG/SSH 提交签名：`git config commit.gpgsign true`，并把公钥添加到 GitHub 账户。
- 仓库目前历史提交未签名（`git log --show-signature` 可查），逐步迁移到签名提交可提升供应链可信度。
- 发布相关密钥：Sparkle EdDSA 私钥文件 `~/AutoToggle-sparkle-private-key.txt` 已 `chmod 600`，请勿提交到仓库或降低权限。

## 供应链

- 依赖钉版与更新见 [SBOM.md](SBOM.md)；第三方许可证见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。
- 发布前运行 `scripts/verify-signing.sh` 作签名门禁。
