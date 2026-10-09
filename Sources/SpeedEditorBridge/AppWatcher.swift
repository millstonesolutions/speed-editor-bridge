import AppKit

/// Reports which application is in front.
final class AppWatcher {
    var onChange: ((String?) -> Void)?
    private(set) var frontmostBundleID: String?

    init() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.frontmostBundleID = app?.bundleIdentifier
            self.onChange?(self.frontmostBundleID)
        }
    }
}

enum KnownApps {
    static let finalCut = ["com.apple.FinalCutApp", "com.apple.FinalCut", "com.apple.FinalCutTrial"]
    static let logic = ["com.apple.mobilelogic", "com.apple.logic10"]
    static let resolve = ["com.blackmagic-design.DaVinciResolve", "com.blackmagic-design.DaVinciResolveLite"]
}
