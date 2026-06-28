# Homebrew Cask for yabai-dockstack.
#
# Put this file in your tap repo at: <you>/homebrew-tap/Casks/yabai-dockstack.rb
# Then users install with:
#   brew install --cask <you>/tap/yabai-dockstack
#
# `brew install --cask` removes the quarantine attribute, so the unsigned app
# launches without a Gatekeeper prompt. Update `version` + `sha256` after each
# release (scripts/release.sh prints the sha256).
cask "yabai-dockstack" do
  version "0.1.0"
  sha256 "d49067cb4c8b237a47d5f739d61d0071b2ceaf483077c15f67dedd2c24b04977"

  url "https://github.com/z20240/yabai-dockstack/releases/download/v#{version}/yabai-dockstack-#{version}.zip"
  name "yabai-dockstack"
  desc "Visual enhancement suite for yabai: stack indicators, window menu, Dock previews"
  homepage "https://github.com/z20240/yabai-dockstack"

  depends_on formula: "koekeishiya/formulae/yabai"

  app "yabai-dockstack.app"

  zap trash: [
    "~/.config/yabai-dockstack",
  ]
end
