class Kiwibar < Formula
  desc "Native macOS menu bar monitor for Bandwagon Host"
  homepage "https://github.com/n0rvyn/kiwibar"
  url "https://github.com/n0rvyn/kiwibar/releases/download/v1.1.0/KiwiBar-1.1.0-source.tar.gz"
  sha256 "268fa5518440fea312d50ed93c1404986d52507f13ee97e8d012648e10cc4bdb"
  version "1.1.0"

  depends_on xcode: ["26.0", :build]
  depends_on macos: :sonoma

  def install
    system "./scripts/build-app.sh", "--distribution"
    prefix.install "dist/KiwiBar.app"
    bin.install_symlink prefix/"KiwiBar.app/Contents/MacOS/KiwiBar" => "kiwibar"
  end

  def caveats
    <<~EOS
      Launch KiwiBar and enter your VEID and API key in Settings:
        open "#{opt_prefix}/KiwiBar.app"
      Credentials are saved in macOS Keychain.
    EOS
  end

  test do
    assert_match "KiwiBar", shell_output("#{bin}/kiwibar --help")
    assert_equal "1.1.0", shell_output("#{bin}/kiwibar --version").strip
  end
end
