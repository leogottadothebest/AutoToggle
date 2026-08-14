#!/bin/zsh
# 创建/复用 AutoToggle 的稳定自签名代码签名证书。
#
# 背景：ad-hoc 签名（CODE_SIGN_IDENTITY="-"）的 designated requirement 是
# `cdhash H"…"`，每次改源码重建都会变，导致 TCC「辅助功能」授权看似保留、实则
# 因 cdhash 不匹配而失效（AXIsProcessTrusted() 返回 false）。
#
# 本脚本用一棵稳定的本地自签名证书（CA:TRUE，含 codeSign 扩展）给 app 签名，
# 使 designated requirement 只依赖 bundle id + 证书，重建不再改变授权身份。
# 证书私钥放在专用钥匙串中；解锁口令改为交互式（M-1），不再写入 login 钥匙串，
# 避免同用户任意进程经 `security find-generic-password -w` 非交互读取口令后重签名。
#
# 幂等：再次运行会复用已有证书与钥匙串，不会覆盖。
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
home_directory="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory | awk '{print $2}')"
keychain_path="${AUTOTOGGLE_KEYCHAIN:-$home_directory/Library/Keychains/AutoToggle.keychain-db}"
identity="${CODESIGN_IDENTITY:-AutoToggle Development}"
login_keychain="$home_directory/Library/Keychains/login.keychain-db"
password_service="AutoToggle Keychain Password"

if [[ -z "$home_directory" || "$keychain_path" == / || "$keychain_path" == "$home_directory" ]]; then
  print -u2 "Refusing an unsafe keychain path"
  exit 64
fi

# M-1：解锁口令改为交互式输入，仅存在于本次运行的内存中，不落盘、不入 login 钥匙串。
# 兼容旧版迁移：若 login 钥匙串还存有早期遗留的口令，先揭示一次（供用户抄录）再删除。
legacy_password="$(security find-generic-password -a "$identity" -s "$password_service" -w "$login_keychain" 2>/dev/null || true)"

if [[ -n "${AUTOTOGGLE_KEYCHAIN_PASSWORD:-}" ]]; then
  keychain_password="$AUTOTOGGLE_KEYCHAIN_PASSWORD"
elif [[ -f "$keychain_path" ]]; then
  if [[ -n "$legacy_password" ]]; then
    print "检测到旧版遗留：login 钥匙串中存有该签名钥匙串的口令（将删除改交互式）。"
    print "请抄录下面显示的口令（仅此一次）："
    print "  $legacy_password"
    keychain_password="$legacy_password"
  elif [[ -t 0 ]]; then
    print -n "输入签名钥匙串口令（$keychain_path）："
    read -rs keychain_password
    print
  else
    print -u2 "非交互环境且钥匙串已存在：请用 AUTOTOGGLE_KEYCHAIN_PASSWORD 提供口令，或到终端交互运行本脚本。"
    exit 65
  fi
  [[ -n "$keychain_password" ]] || { print -u2 "未输入口令"; exit 65; }
else
  # 首次创建：交互式设置口令（两次确认）；非交互时须通过环境变量提供。
  if [[ -t 0 ]]; then
    print "首次运行：请为签名钥匙串设置口令（用于解锁代码签名证书，请牢记；遗失需重新生成证书）。"
    while true; do
      print -n "口令："; read -rs keychain_password; print
      print -n "确认："; read -rs confirm_password; print
      [[ -n "$keychain_password" && "$keychain_password" == "$confirm_password" ]] && break
      print -u2 "两次输入不一致或为空，请重试。"
    done
  else
    print -u2 "非交互环境：请通过 AUTOTOGGLE_KEYCHAIN_PASSWORD 环境变量提供口令后再运行。"
    exit 65
  fi
fi

# 删除旧版遗留口令（M-1 落地：消除「同用户任意进程非交互读取口令」的通道）。
security delete-generic-password -a "$identity" -s "$password_service" "$login_keychain" >/dev/null 2>&1 || true

if [[ ! -f "$keychain_path" ]]; then
  mkdir -p "$(dirname "$keychain_path")"
  security create-keychain -p "$keychain_password" "$keychain_path" >/dev/null
  security set-keychain-settings -lut 21600 "$keychain_path"
fi
security unlock-keychain -p "$keychain_password" "$keychain_path"

# 把专用钥匙串加入用户搜索列表（幂等），使 codesign/xcodebuild 能找到该身份。
current_list=("${(@f)$(security list-keychains -d user 2>/dev/null | sed -E 's/^[[:space:]]*"([^"]*)"[[:space:]]*$/\1/')}")
if ! (( ${current_list[(Ie)$keychain_path]} )); then
  security list-keychains -d user -s "$keychain_path" "${current_list[@]}" >/dev/null 2>&1 || true
fi

scratch_path="$(mktemp -d "${TMPDIR:-/tmp}/autotoggle-signing-cert.XXXXXX")"
trap 'find "$scratch_path" -depth -delete 2>/dev/null || true' EXIT
key_path="$scratch_path/private-key.pem"
certificate_path="$scratch_path/certificate.pem"
bundle_path="$scratch_path/certificate.p12"

if security find-certificate -c "$identity" "$keychain_path" >/dev/null 2>&1; then
  print "Using existing certificate: $identity"
else
  # CA:TRUE 是关键：非 CA 叶证书无法作为自身信任根，会导致 find-identity 找不到有效身份。
  openssl req -new -x509 -newkey rsa:4096 -nodes -days 3650 \
    -subj "/CN=$identity/O=AutoToggle/OU=Development" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign,cRLSign" \
    -addext "extendedKeyUsage=codeSigning" \
    -keyout "$key_path" -out "$certificate_path" >/dev/null 2>&1
  import_password="$(openssl rand -hex 24)"
  openssl pkcs12 -export -out "$bundle_path" -inkey "$key_path" -in "$certificate_path" \
    -passout pass:"$import_password" -legacy >/dev/null 2>&1
  security import "$bundle_path" -k "$keychain_path" -P "$import_password" \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null
  unset import_password
  # 顺序关键：先 set-key-partition-list 授权 security 访问该钥匙串，再 add-trusted-cert。
  # 若顺序颠倒，add-trusted-cert 会弹 GUI 授权框（headless 下卡死）。
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
    -k "$keychain_password" "$keychain_path" >/dev/null
  # 仅作用域于当前用户 + 代码签名策略，不改动系统信任。
  security add-trusted-cert -r trustRoot -p codeSign -k "$keychain_path" "$certificate_path" >/dev/null
  print "Created certificate: $identity"
fi

if ! security find-identity -v -p codesigning "$keychain_path" | grep -Fq "\"$identity\""; then
  print -u2 "证书不是有效的本地代码签名身份: $identity"
  exit 70
fi

# 自检：确认本次输入/设置的口令确实能解锁钥匙串（口令不再写入 login 钥匙串）。
if ! security unlock-keychain -p "$keychain_password" "$keychain_path" >/dev/null 2>&1; then
  print -u2 "自检失败：无法用本次口令解锁签名钥匙串"
  exit 72
fi
print "自检通过：钥匙串可用（口令为交互式，未持久化）"

certificate_pem="$scratch_path/selected-certificate.pem"
security find-certificate -c "$identity" -p "$keychain_path" > "$certificate_pem"
certificate_sha256="$(openssl x509 -in "$certificate_pem" -noout -fingerprint -sha256 | sed 's/.*=//; s/://g')"
certificate_sha1="$(openssl x509 -in "$certificate_pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"

print "Publisher certificate SHA-256: $certificate_sha256"
print "Publisher certificate SHA-1:   $certificate_sha1"
print "Keychain: $keychain_path"
print "Identity: $identity"
