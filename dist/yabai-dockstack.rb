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
  version "0.4.0"
  sha256 "1aa31ff35e3ddb510ba7856ac5af6800627940fdb3b4335563780e18a543deb5"

  url "https://github.com/z20240/yabai-dockstack/releases/download/v#{version}/yabai-dockstack-#{version}.zip"
  name "yabai-dockstack"
  desc "Visual enhancement suite for yabai: stack indicators, window menu, Dock previews"
  homepage "https://github.com/z20240/yabai-dockstack"

  app "yabai-dockstack.app"

  # The app is ad-hoc signed but not Apple-notarized, so Gatekeeper would block it.
  # Strip the quarantine attribute on install so it opens without the prompt.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/yabai-dockstack.app"]
  end

  # yabai is required but lives in a third-party tap, which `depends_on` can't
  # auto-tap — so we guide the user instead (the app also guides on first launch).
  caveats <<~EOS
    yabai-dockstack requires yabai (not installed automatically). Install + start it:

      brew tap koekeishiya/formulae
      brew install yabai
      yabai --start-service

    Full window management also needs yabai's own setup (partially disabling SIP).
    See: https://github.com/koekeishiya/yabai/wiki
  EOS

  zap trash: [
    "~/.config/yabai-dockstack",
  ]
end
