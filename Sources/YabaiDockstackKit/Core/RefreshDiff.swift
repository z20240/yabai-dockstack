public enum RefreshDiff {
    public static func shouldRedraw(old: [Stack], new: [Stack]) -> Bool {
        if old.count != new.count { return true }
        func signature(_ stacks: [Stack]) -> [String] {
            stacks.map { s in
                "\(s.key)#\(s.windows.map { String($0.id) }.joined(separator: ","))#\(s.isFocused)#\(s.windows.first { $0.hasFocus }?.id ?? -1)"
            }.sorted()
        }
        return signature(old) != signature(new)
    }
}
