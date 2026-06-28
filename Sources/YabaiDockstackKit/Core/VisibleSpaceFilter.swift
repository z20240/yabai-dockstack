/// Keeps only windows that live on a *currently visible* space.
///
/// A yabai stack shows only its active member on top, so the occluded members
/// report `is-visible == false`. We therefore can't filter windows by their own
/// visibility — instead we find the set of spaces that contain at least one
/// visible window (i.e. the spaces currently shown on each display) and keep all
/// windows on those spaces. This drops stacks that live on other spaces (so they
/// don't bleed across spaces) and avoids drawing over native-fullscreen spaces.
public enum VisibleSpaceFilter {
    public static func apply(_ windows: [YabaiWindow]) -> [YabaiWindow] {
        let visibleSpaces = Set(windows.filter { $0.isVisible }.map { $0.space })
        guard !visibleSpaces.isEmpty else { return windows }  // safety: don't hide everything
        return windows.filter { visibleSpaces.contains($0.space) }
    }
}
