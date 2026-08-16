#!/usr/bin/env bash
# 构建 Release 版 AutoToggle 到 build/DerivedData
set -euo pipefail
cd "$(dirname "$0")/.."

# ---- 解锁稳定签名钥匙串 ----
# 项目用 scripts/bootstrap-signing.sh 生成的稳定自签名证书签名（非 ad-hoc）。
# M-1：解锁口令改为交互式，不再从 login 钥匙串非交互读取（也不在命令行携带口令）。
# 仅当钥匙串确实锁定时才交互解锁；已解锁（6 小时自动锁定窗口内）则静默跳过。
# show-keychain-info 对已解锁钥匙串返回 0、对锁定钥匙串返回非零。
KEYCHAIN="$HOME/Library/Keychains/AutoToggle.keychain-db"
IDENTITY="AutoToggle Development"

if [[ -f "$KEYCHAIN" ]]; then
  if ! security show-keychain-info "$KEYCHAIN" >/dev/null 2>&1; then
    if ! security unlock-keychain "$KEYCHAIN"; then
      echo "❌ 无法解锁签名钥匙串 $KEYCHAIN（交互解锁失败/被取消，或非交互环境下已锁定）。" >&2
      echo "   请在有终端的目录手动运行 scripts/build.sh 并输入口令解锁。" >&2
      exit 1
    fi
  fi
fi

if ! security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$IDENTITY\""; then
  echo "❌ 找不到签名身份「$IDENTITY」。请先运行 scripts/bootstrap-signing.sh" >&2
  exit 1
fi

if command -v xcodegen >/dev/null 2>&1; then
  echo "▶ 生成 Xcode 工程 (xcodegen)"
  xcodegen generate
else
  echo "ℹ 未安装 xcodegen，沿用现有 AutoToggle.xcodeproj"
fi

echo "▶ 构建 Release（签名身份: $IDENTITY）"
xcodebuild -project AutoToggle.xcodeproj \
  -scheme AutoToggle \
  -configuration Release \
  build \
  -derivedDataPath build/DerivedData

echo "▶ 校验通用二进制 (lipo：arm64 + x86_64)"
lipo -archs "build/DerivedData/Build/Products/Release/AutoToggle.app/Contents/MacOS/AutoToggle" | grep -q x86_64 || {
  echo "❌ 产物不是通用二进制（缺少 x86_64）。请检查 project.yml 的 ARCHS 设置。" >&2
  exit 1
}

echo "▶ 校验签名门禁 (verify-signing.sh)"
./scripts/verify-signing.sh "build/DerivedData/Build/Products/Release/AutoToggle.app"

echo "✅ 构建完成并通过签名门禁: build/DerivedData/Build/Products/Release/AutoToggle.app"
