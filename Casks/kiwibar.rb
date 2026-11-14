cask "kiwibar" do
  version "1.2.1"
  sha256 "0b29dc26bb787fdcc2378e4114da3b35d67167f1bd2c7b83135a125aec38ed03"

  url "https://github.com/n0rvyn/kiwibar/releases/download/v#{version}/KiwiBar-#{version}.zip?download=1"
  name "KiwiBar"
  desc "Menu bar monitor for Bandwagon Host"
  homepage "https://github.com/n0rvyn/kiwibar"

  depends_on macos: :sonoma

  app "KiwiBar.app"
end
