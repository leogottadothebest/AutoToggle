# AutoToggle 1.3.0 安全审计报告

- **审计对象**：AutoToggle **1.3.0**（`release/1.x` 离线稳定线，`MARKETING_VERSION=1.3.0`，build 4）
- **审计日期**：2026-08-16
- **审计方式**：全量源码静态安全审计 + 7 个安全维度并行评审 + 逐条对抗性复核（adversarial verification）
- **结论等级**：**中低风险**（无 Critical/High 级可利用漏洞；存在 1 个中危、若干低危/信息级问题，均可通过小改动收敛）

---

## 一、执行摘要（TL;DR）

1.3.0 是一条**刻意精简的攻击面**的发布线：**零第三方运行时依赖、零网络请求、无自动更新（Sparkle）**。核心的防注入与防滥用控制做得扎实——Bundle ID 在进入 AppleScript 前有严格白名单正则校验、配置导入有界读取与范围钳制、强制退出有 PID 复用护栏、签名有 5 项门禁脚本兜底。

**未发现**可远程利用、可提权或可导致任意代码执行的 Critical/High 级漏洞。

主要风险集中在两处**设计性权衡**而非代码缺陷：
1. **未启用 App Sandbox**（应用以完整用户权限运行）——这是为支持「强制退出/隐藏其它应用」而作的、已在文档中声明过的取舍，但它把「进程一旦被攻破」的爆炸半径放大到了「可读写用户全部文件、可借用已授予的自动化授权」。属**接受但需持续警惕**的风险。
2. **自签名证书 + 未公证（notarized）**——发布产物没有 Apple 的「已认证开发者」锚点，用户首次运行需绕过 Gatekeeper，且无法用签名区分「官方版本」与「被篡改的版本」。属**分发信任**风险。

另有一个真实的**中危代码缺陷**：强制退出链路中，`forceTerminate()` 阶段只按 bundle ID 重查、未校验 PID 是否还是同一实例，存在 3 秒窗口内误杀「用户刚重新打开的同款应用」的可能（CWE-362）。

其余为低危/信息级：日志注入（导入的应用名未剥离控制字符）、密钥在进程 argv 中短暂暴露、`os.Logger` 用 `.public` 泄漏 bundle ID、构建工具链未钉版等。

---

## 二、审计范围与方法

| 项 | 说明 |
|---|---|
| **代码来源** | `release/1.x` 分支 HEAD（`d4fc371`），等价于 1.3.0 离线稳定线 |
| **技术栈** | SwiftUI + SwiftData，Swift 6，macOS 14.0+，通用二进制（arm64 + x86_64） |
| **分发形态** | DMG，稳定自签名证书（`AutoToggle Development`），无第三方运行时组件 |
| **权限** | 辅助功能（TCC）、Apple Events（自动化）、IOKit 电源断言 |
| **方法** | ① 逐文件通读安全关键代码；② 7 个维度并行评审（注入 / 权限 / 供应链 / 隐私 / 输入校验 / 竞态 / 网络面）；③ 对每个发现做对抗性复核（尝试证伪，仅保留可复现、可达的项） |

**已确认的攻击面清单**（供参考）：配置 JSON 导入、辅助功能 AX 读取、AppleScript 自动化、NSWorkspace 通知、IOKit、分布式通知（`com.apple.accessibility.api`）。**已核实零网络调用**（全源码无 URLSession/NWConnection/socket/curl/WebKit）。

---

## 三、已确认的安全发现

### 中危（Medium）

#### M-1 · 强制退出阶段误杀「重新打开」的应用实例（CWE-362）
- **位置**：[AppActionManager.swift:130](AutoToggle/Managers/AppActionManager.swift:130)
- **描述**：三级退出「AppleScript → `terminate()` → `forceTerminate()`」中，已有的 LOW-4 PID 复用护栏**只覆盖了 `terminate()` 一步**（第 120–121 行先按 bundle ID 重查并校验 PID 未变）。但 3 秒延迟后的 `forceTerminate()`（第 130–131 行）**只按 bundle ID 重查、只判断 `!isTerminated`，不再校验 PID**。
- **攻击/触发场景**：用户对某应用设了「强制退出」规则。AppleScript 优雅退出失败 → `terminate()` 给实例 P1 发信号 → P1 开始退出 → 用户在这 3 秒内重新打开了同款应用得到新实例 P2 → 第 130 行解析到 P2 → `forceTerminate()` 误杀 P2，导致新实例未保存的工作丢失。
- **性质**：非攻击者可控（用户自己机器上的自伤竞态），窗口窄（3 秒），但会导致真实数据丢失。
- **修复建议**：在 `terminate()` 前捕获目标 PID（第 121 行的 `current.processIdentifier`），闭包内一并捕获；`forceTerminate()` 前重新解析并要求 `current.processIdentifier == 捕获的 PID`，否则跳过。即把 LOW-4 护栏补齐到第三级。

### 低危（Low）

#### L-1 · 自签名证书 + 未公证，缺少真实性与吊销锚点（CWE-295）
- **位置**：[project.yml:40](project.yml:40)
- **描述**：Release 用自签名证书（`CA:TRUE`、RSA-4096、10 年）签名，未公证。自签名证书无法通过 Apple 公证，因此 DMG 无「已认证开发者」标识。
- **影响**：用户首次运行会被 Gatekeeper 拦截、需手动绕过（右键打开或 `xattr -dr com.apple.quarantine`）；且由于用户本就要绕过 Gatekeeper，一个被第三方篡改的二进制在用户眼里与官方版本**无法区分**，弱化了完整性保障。
- **建议**：如可行，接入 Apple Developer ID 证书 + 公证 + 装订（stapling）；至少在 README/Release 页显式给出 DMG 的 SHA-256 供用户核对，并把签名证书指纹固定发布。

#### L-2 · 签名钥匙串口令通过进程 argv 传递（CWE-522）
- **位置**：[bootstrap-signing.sh:70/73/105/118](scripts/bootstrap-signing.sh:70)
- **描述**：`security create-keychain/unlock-keychain/set-key-partition-list -p/-k "$keychain_password"` 将口令放在命令行参数上。
- **影响**：同用户（或 root）进程可在 `ps` / 进程快照中短暂读到该口令，进而解锁专用签名钥匙串、重签名。窗口短、需本机访问，故为低危。
- **建议**：改用 `security unlock-keychain` 的交互式输入，或经 stdin/临时文件（`chmod 600`、用完即删）传递口令，避免出现在 argv。

#### L-3 · 迁移路径把旧签名口令打印到 stdout（CWE-532）
- **位置**：[bootstrap-signing.sh:38](scripts/bootstrap-signing.sh:38)
- **描述**：检测到 login 钥匙串残留旧口令时，`print "  $legacy_password"` 明文回显。
- **影响**：一次性迁移路径，但口令会出现在终端滚动日志/录屏/CI 输出中。
- **建议**：改为「提示用户自行到钥匙串查看」，或回显前加交互确认且不落任何日志。

#### L-4 · 导入的应用名/方案名未剥离控制字符，构成日志注入（CWE-117）
- **位置**：[ProfileManager.swift:158/170](AutoToggle/Managers/ProfileManager.swift:158)
- **描述**：`importProfile` 对 `profileName`/`appName` 只做 `String(prefix:)` 长度截断，**未剥离换行/控制字符**（注释声称能防控制字符污染，但 `prefix` 并不剥离）。这些字符串会进入 SwiftData 日志（`LogEntry.message`）与导出诊断报告。
- **影响**：恶意配置可注入换行 + 伪造日志行（如 `\n[时间] [系统] 已卸载`），误导查看日志/报告的人（CWE-117 日志伪造）。
- **建议**：与 `renameProfile` 一致，截断前先剥离 C0/C1 控制字符与换行（可复用同一清洗函数）。

#### L-5 · `os.Logger` 用 `.public` 泄漏 bundle ID 与错误描述（CWE-532）
- **位置**：[AppActionManager.swift:50/68/153](AutoToggle/Managers/AppActionManager.swift:50)、[AppDependencies.swift:32/103](AutoToggle/AppDependencies.swift:32)
- **描述**：`Log.appAction.warning("…\(bundleID, privacy: .public)…")` 等把 bundle ID、`localizedDescription` 标为 `.public`。
- **影响**：这些值以明文进入统一日志（Console.app / `log show`），同用户进程或管理员可读。bundle ID 本身不算高敏，但暴露用户「装了哪些应用、何时被操作」的使用画像。
- **建议**：默认改用 `.private`（自动脱敏为 `<private>`），仅确需诊断时对少数字段显式 `.public`。

#### L-6 · 构建/静态检查工具链未钉版（CWE-1357）
- **位置**：[Brewfile:1](Brewfile:1)、[.github/workflows/ci.yml:20/40](.github/workflows/ci.yml:20)
- **描述**：Brewfile 里 `xcodegen`/`mint` 未钉版本；CI 用 `brew install xcodegen swiftlint` 装最新版（`Mintfile` 已钉 SwiftLint/SwiftFormat，但 CI 未走 Mintfile）。
- **影响**：供应链层面，工具链「漂移」可能引入不可复现的构建/检查差异；仅影响 CI（CI 只跑 Debug 构建+测试，不产出发布二进制），故为低危。
- **建议**：Brewfile 钉版本，CI 改用 Mintfile 的钉版版本（`mint run swiftlint`）。

#### L-7 · 导入的 `idleMinutes` 范围与全应用不一致（CWE-20）
- **位置**：[ProfileManager.swift:187](AutoToggle/Managers/ProfileManager.swift:187)
- **描述**：导入解析把 `idleMinutes` 钳制在 `1...720`，而 UI 与解码层用的是 `1...1440`（`TimeTrigger.swift`、`IdleTriggerPicker`）。
- **影响**：>720 分钟的闲置规则经「导出→导入」往返会被静默丢弃。属一致性/健壮性缺陷，非直接安全漏洞。
- **建议**：统一为 `1...1440`，与 `IdleTrigger` 解码钳制保持一致。

#### L-8 · 定时去重键不含日期、清理依赖连续分钟 tick（CWE-372）
- **位置**：[ScheduleManager.swift:135](AutoToggle/Managers/ScheduleManager.swift:135)
- **描述**：`triggerKey = "ruleID:hour:minute"` 不含日期；`cleanupTriggeredKeys` 用 `key.hasSuffix("hour:minute")` 过滤。若某分钟 tick 被跳过（如系统休眠唤醒），跨日同「时:分」可能重复触发，或清理误保留/误删。
- **影响**：极端时序下定时规则可能重复执行或漏执行。低危（无安全后果，但影响正确性）。
- **建议**：键中加入日期（`yyyymmdd-HH:mm`），清理按完整键或固定窗口裁剪。

#### L-9 · 配置导出非原子写入且跟随符号链接（CWE-59）
- **位置**：[ProfileManager.swift:124](AutoToggle/Managers/ProfileManager.swift:124)
- **描述**：`try? jsonData.write(to: url)` 未用 `.atomic`；`Data.write` 默认 `O_CREAT|O_TRUNC` 且跟随 symlink。
- **影响**：用户选择路径若为符号链接，导出会写入链接目标；中断可能留下半截文件。信息/低危（用户自选路径、本机操作）。
- **建议**：改用 `.atomic` 写入。

### 信息级（Info）

#### I-1 · 未启用 App Sandbox（CWE-250，已声明的设计权衡）
- **位置**：[project.yml:29](project.yml:29)
- **描述**：Hardened Runtime 开启，但无 `com.apple.security.app-sandbox`；授权仅 `com.apple.security.automation.apple-events`。应用以完整用户权限运行。
- **影响**：进程若被攻破，可读写用户全部文件（文档、浏览器配置、SSH 密钥等）、访问自身身份下的钥匙串项，并借用用户已授予的「自动化」授权向被管应用发任意 Apple Events（自动化授权按「来源×目标」授予、不限命令）。摄像头/麦克风 TCC **不会**自动继承，需单独弹窗。
- **说明**：RELEASE.md 已明确记录该取舍（强制退出/隐藏其它应用需要）。**维持现状可接受**，但建议：在 SECURITY.md 补一句爆炸半径说明；并保持 AppleScript 仅限固定的 quit/hide 命令、不扩展「任意脚本」能力。

#### I-2 · SwiftData 存储明文（CWE-312）
- **位置**：[AppDependencies.swift:27](AutoToggle/AppDependencies.swift:27)
- **描述**：`~/Library/Application Support/default.store` 明文存储规则（bundle ID、应用名）与活动日志（哪些应用在何时被启动/退出）。
- **影响**：任何能读该文件的同用户/备份者可见用户的应用使用画像。属本地隐私项，非加密需求（无跨设备上传）。
- **建议**：若需更严格，可考虑对 store 施加文件级保护或对敏感字段加密；当前「本地隐私优先」定位下可接受。

#### I-3 · 诊断导出内嵌应用名/使用时间戳，无脱敏与提示（CWE-200）
- **位置**：[DiagnosticsManager.swift:59](AutoToggle/Managers/DiagnosticsManager.swift:59)
- **描述**：导出的 `.txt` 含版本、系统版本、权限状态、规则数、近 50 条日志（含应用名、bundle ID、操作时间戳），写入用户自选路径、不自动上传。
- **影响**：用户把报告附到 Issue 时可能无意中泄露自己装了哪些应用及其使用时间。信息级。
- **建议**：导出前在界面给一句「报告含应用使用记录」提示，或提供「仅系统信息」脱敏选项。

---

## 四、经复核已排除的发现（非漏洞）

以下 4 项经对抗性复核判定为**不成立或影响不成立**，特此记录以免误报：

1. **「配置库/导入配置可驱动任意进程控制」** —— 复核不成立：导入的 bundle ID 经 `isValidBundleID` 白名单校验，且自动化 TCC 授权按目标逐应用授予、应用只执行固定的 quit/hide/launch 命令，未跨过特权边界。
2. **「损坏 store 恢复可能半途中断并 fatalError」** —— 复核不成立：`moveItem` 逐文件原子、失败可重试，`fatalError` 仅在「备份重建也失败」的最后兜底才触发，属可接受的最后手段。
3. **「system 级闲置规则的 alreadyTriggered 锁被错误事件重置」** —— 复核不成立：该锁在「系统恢复活跃」时本就不该重置，其行为符合「每次闲置周期只触发一次」的预期。
4. **「MainActor 上同步 AppleScript 会阻塞并跳过定时 tick」** —— 复核不成立：`NSAppleScript.executeAndReturnError` 快速返回、3 秒 forceTerminate 已异步化，无实际 timer 跳过影响。

---

## 五、已验证到位的正面控制（值得保留）

| 控制 | 位置 | 说明 |
|---|---|---|
| Bundle ID 白名单防注入 | [BundleHelper.swift:27](AutoToggle/Utilities/BundleHelper.swift:27) | `^[A-Za-z0-9][A-Za-z0-9.-]*$` + ≤255，覆盖**所有**进入 AppleScript 的路径（launch/quit/hide/activate 与导入），杜绝引号/反斜杠注入（CWE-94） |
| 配置导入有界读取 | [ProfileManager.swift:134-203](AutoToggle/Managers/ProfileManager.swift:134) | 1MB+1 哨兵、≤200 条规则、hour/minute/weekday/idleMinutes 范围校验、名称截断（防 CWE-400 资源耗尽与 symlink TOCTOU） |
| `terminate()` PID 复用护栏 | [AppActionManager.swift:120-121](AutoToggle/Managers/AppActionManager.swift:120) | 优雅退出后先按 bundle ID 重查并校验 PID 未变，再 `terminate()`（部分缓解 CWE-362） |
| `IdleTrigger` 解码钳制 | [TimeTrigger.swift:72-78](AutoToggle/Models/TimeTrigger.swift:72) | `idleMinutes` 钳制 `1...1440`，防 `*60` 溢出与立即误触发 |
| 签名 5 项门禁 | [verify-signing.sh](scripts/verify-signing.sh) | 强制校验 Hardened Runtime、无 `get-task-allow`、apple-events、无 Debug 产物、非 ad-hoc，已接入构建后 |
| 钥匙串隔离 | [bootstrap-signing.sh](scripts/bootstrap-signing.sh) | 专用钥匙串、口令交互式（不入 login 钥匙串）、`set-key-partition-list` 限定 codesign/security 访问 |
| 损坏 store 备份重建 | [AppDependencies.swift:84-106](AutoToggle/AppDependencies.swift:84) | 损坏时备份 `.corrupt-<时间戳>` 后重建空库，不硬崩、不丢数据 |
| 零网络 | 全源码 grep | 无 URLSession/NWConnection/socket/curl/WebKit，唯一 `Process` 为固定 `/usr/bin/open`（重启/打开系统设置） |
| 隐私文案 | [Info.plist:25](AutoToggle/Info.plist:25) | `NSAppleEventsUsageDescription` 已声明 |

---

## 六、总体评价与优先级建议

**总体评价**：1.3.0 的安全基线高于多数同类小工具——注入与滥用面收得很紧，离线化极大缩小了威胁面。剩余问题多为「把已经很紧的边界再收窄半格」的打磨项，以及两项需要产品层面决策的权衡（Sandbox、公证）。

**建议优先级**：

1. **P1（建议尽快）**：修复 M-1（`forceTerminate` 补 PID 校验）——几行改动即可消除误杀他人工作实例的数据丢失风险。
2. **P1**：修 L-4（导入名称剥离控制字符）——消除日志注入，成本极低。
3. **P2**：L-1 公证 / 或至少发布 DMG SHA-256 + 固定证书指纹；L-2/L-3 密钥处理改用非 argv 传递。
4. **P2**：L-5 统一日志改 `.private`；L-6 工具链钉版。
5. **P3**：L-7/L-8/L-9 的一致性/健壮性小修；I-1 在 SECURITY.md 补爆炸半径说明；I-3 导出加提示。

---

*本报告由 Claude（Fable 5）自动生成，基于对 `release/1.x` 全量源码的静态审计与多维度对抗性复核。结论仅供开发参考，不构成对二进制产物的运行时验证或对第三方分发通道的背书。*
