#!/usr/bin/env bash
# 构建 Release 版 AutoToggle 到 build/DerivedData
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v xcodegen >/dev/null 2>&1; then
  echo "▶ 生成 Xcode 工程 (xcodegen)"
  xcodegen generate
else
  echo "ℹ 未安装 xcodegen，沿用现有 AutoToggle.xcodeproj"
fi

echo "▶ 构建 Release"
xcodebuild -project AutoToggle.xcodeproj \
  -scheme AutoToggle \
  -configuration Release \
  build \
  -derivedDataPath build/DerivedData

echo "✅ 构建完成: build/DerivedData/Build/Products/Release/AutoToggle.app"
