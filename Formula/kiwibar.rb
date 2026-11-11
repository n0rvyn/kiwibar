class Kiwibar < Formula
  desc "Native macOS menu bar monitor for Bandwagon Host"
  homepage "https://github.com/n0rvyn/kiwibar"
  url "https://github.com/n0rvyn/kiwibar/releases/download/v1.0.0/KiwiBar-1.0.0-source.tar.gz"
  sha256 "558050d33ce83fa6a7370b5f7454d53737bde64be1009ea2d0593b7b8f98ab56"
  version "1.0.0"

  depends_on xcode: ["26.0", :build]
  depends_on macos: :sonoma

  def install
    system "./scripts/build-app.sh", "--distribution"
    prefix.install "dist/KiwiBar.app"
    bin.install_symlink prefix/"KiwiBar.app/Contents/MacOS/KiwiBar" => "kiwibar"
    pkgshare.install ".env.example"
  end

  def caveats
    <<~EOS
      Put VEID and API_KEY in ~/.config/kiwibar/.env, then launch:
        open "#{opt_prefix}/KiwiBar.app"
      Example configuration: #{pkgshare}/.env.example
    EOS
  end

  test do
    assert_match "KiwiBar", shell_output("#{bin}/kiwibar --help")
    assert_equal "1.0.0", shell_output("#{bin}/kiwibar --version").strip
  end
end
