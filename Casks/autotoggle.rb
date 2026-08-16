cask "autotoggle" do
  version "2.1.0"
  # ⚠️ 发布 DMG 后用 `shasum -a 256 AutoToggle-2.1.0.dmg` 填入真实哈希
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/leogottadothebest/AutoToggle/releases/download/v#{version}/AutoToggle-#{version}.dmg"
  name "AutoToggle"
  desc "Privacy-first, rule-driven app launcher & terminator for macOS"
  homepage "https://github.com/leogottadothebest/AutoToggle"

  depends_on macos: ">= :sonoma"

  app "AutoToggle.app"

  caveats do
    "AutoToggle 使用自签名证书（未经 Apple 公证），首次启动需右键 → 打开 绕过 Gatekeeper。详见 https://github.com/leogottadothebest/AutoToggle#-faq--troubleshooting"
  end
end
