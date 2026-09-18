cask "autotoggle" do
  version "2.2.2"
  # 发布 DMG 后用 `shasum -a 256 AutoToggle-2.2.2.dmg` 填入真实哈希
  sha256 "2ee16f23a5bd767f963c65d31eed8322e9d2bb8eabbe4663626ff47a2cd1ea03"

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
