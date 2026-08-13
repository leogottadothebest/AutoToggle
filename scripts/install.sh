#!/usr/bin/env bash
# 构建并直接覆盖 /Applications 中的 AutoToggle.app（原子替换，不留旧版）
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DerivedData/Build/Products/Release/AutoToggle.app"
DEST="/Applications/AutoToggle.app"

if [ ! -d "$APP" ]; then
  echo "▶ 未找到构建产物，先构建"
  "$(dirname "$0")/build.sh"
fi

if [ ! -d "$APP" ]; then
  echo "❌ 构建产物缺失: $APP" >&2
  exit 1
fi

# 优雅退出正在运行的实例（避免文件占用）
if pgrep -x AutoToggle >/dev/null 2>&1; then
  echo "▶ 退出正在运行的 AutoToggle"
  osascript -e 'quit app "AutoToggle"' 2>/dev/null || true
  sleep 1
fi

echo "▶ 直接覆盖 $DEST（先暂存到 .staging 再原子替换，不留旧版残留/版本号副本）"
STAGING="$DEST.staging"
rm -rf "$STAGING"
ditto "$APP" "$STAGING"
rm -rf "$DEST"
mv "$STAGING" "$DEST"

echo "✅ 已覆盖最新版到 /Applications/AutoToggle.app"
