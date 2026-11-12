cask "kiwibar" do
  version "1.2.0"
  sha256 "010b89449cb4a0291a9089b18d8f32b9fab5b783d81be8c0f84c59ac1d2fecde"

  url "https://github.com/n0rvyn/kiwibar/releases/download/v#{version}/KiwiBar-#{version}.zip?download=1"
  name "KiwiBar"
  desc "Menu bar monitor for Bandwagon Host"
  homepage "https://github.com/n0rvyn/kiwibar"

  depends_on macos: :sonoma

  app "KiwiBar.app"
end
