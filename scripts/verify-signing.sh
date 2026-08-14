#!/bin/bash
# 验证 Release 构建的签名安全性（LOW-8：自动化门禁，替代手动 codesign | grep）
# 用法：scripts/verify-signing.sh [App路径]
set -euo pipefail

APP="${1:-build/DerivedData/Build/Products/Release/AutoToggle.app}"

if [[ ! -d "$APP" ]]; then
  echo "❌ 找不到应用: $APP"
  exit 1
fi

echo "验证: $APP"

# ① Hardened Runtime 标志（CodeDirectory 行含 "runtime"）
cdline=$(codesign -dv --verbose=4 "$APP" 2>&1 | grep '^CodeDirectory')
if ! echo "$cdline" | grep -q 'runtime'; then
  echo "❌ 缺少 Hardened Runtime (runtime) 标志: ${cdline:-<无 CodeDirectory 行>}"
  exit 1
fi
echo "✅ Hardened Runtime: $(echo "$cdline" | grep -o 'flags=[^ ]*')"

# ② 无 get-task-allow（调试授权，允许任意进程附加注入）
if codesign -d --entitlements - "$APP" 2>&1 | grep -q 'get-task-allow'; then
  echo "❌ 含 get-task-allow 调试授权"
  exit 1
fi
echo "✅ 无 get-task-allow"

# ③ apple-events 授权存在
if ! codesign -d --entitlements - "$APP" 2>&1 | grep -q 'com.apple.security.automation.apple-events'; then
  echo "❌ 缺少 apple-events 授权"
  exit 1
fi
echo "✅ apple-events 授权"

# ④ 无 Debug 产物
if ls "$APP/Contents/MacOS/" | grep -qE '\.debug\.dylib|__preview'; then
  echo "❌ 含 Debug 产物"
  exit 1
fi
echo "✅ 无 Debug 产物"

# ⑤ 非 ad-hoc 签名（稳定自签名证书，designated requirement 不依赖 cdhash）
#    ad-hoc 签名会让 TCC 辅助功能授权在每次重建后失效，必须用稳定证书。
if codesign -dv --verbose=4 "$APP" 2>&1 | grep '^CodeDirectory' | grep -q 'adhoc'; then
  echo "❌ ad-hoc 签名（会导致辅助功能授权在重建后失效），应使用 scripts/bootstrap-signing.sh 的稳定证书"
  exit 1
fi
echo "✅ 非 ad-hoc（稳定自签名证书）"

echo "✅ 全部签名检查通过"
