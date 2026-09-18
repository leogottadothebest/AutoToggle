cask "autotoggle" do
  version "2.2.1"
  # 发布 DMG 后用 `shasum -a 256 AutoToggle-2.2.1.dmg` 填入真实哈希
  sha256 "b1953c21d44f5b0b04cb318cc7bf8f4f07fc5adc765269d79934e6820b8a09c1"

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
