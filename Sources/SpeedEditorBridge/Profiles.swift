import Foundation
import SpeedEditorKit

extension SpeedEditorKey: Identifiable {
    public var id: UInt16 { rawValue }
    var name: String { String(describing: self) }
    init?(name: String) {
        guard let k = SpeedEditorKey.allCases.first(where: { $0.name == name }) else { return nil }
        self = k
    }
}

/// Everything the engine needs to drive one application.
struct Profile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var bundleIDs: [String]
    /// Key name -> action.
    var keys: [String: Action]
    var jog: WheelOutput
    var scroll: WheelOutput
    var shuttle: ShuttleStyle
    var framesPerRevolution: Double
    /// Encoder ticks per scroll step.
    var scrollTicksPerStep: Int
    /// Holding one of these keys while turning the wheel sends these keys instead.
    var holdWheel: [String: WheelKeys]
    var releaseForResolve: Bool

    func action(for key: SpeedEditorKey) -> Action { keys[key.name] ?? .none }

    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }()
}

enum DefaultProfiles {
    static let all: [Profile] = [finalCut, logic, generic]

    static func profile(id: String) -> Profile? { all.first { $0.id == id } }

    private static func k(_ s: String) -> KeyCombo { KeyCombo(parsing: s)! }

    static let finalCut = Profile(
        id: "fcp",
        name: "Final Cut Pro",
        bundleIDs: KnownApps.finalCut,
        keys: [
            "smartInsert": .keystroke(k("w")),
            "append": .keystroke(k("e")),
            "rippleOverwrite": .keystroke(k("d")),
            "closeUp": .none,
            "placeOnTop": .keystroke(k("q")),
            "sourceOverwrite": .keystroke(k("shift+r")),
            "markIn": .keystroke(k("i")),
            "markOut": .keystroke(k("o")),
            "trimIn": .keystroke(k("opt+[")),
            "trimOut": .keystroke(k("opt+]")),
            "roll": .keystroke(k("t")),
            "slipSource": .none,
            "slipDestination": .none,
            "transitionDuration": .keystroke(k("ctrl+d")),
            "cut": .keystroke(k("cmd+b")),
            "dissolve": .keystroke(k("cmd+t")),
            "smoothCut": .none,
            "source": .keystroke(k("cmd+1")),
            "timeline": .keystroke(k("cmd+3")),
            "shuttle": .wheelMode(.shuttle),
            "jog": .wheelMode(.jog),
            "scroll": .wheelMode(.scroll),
            "syncBin": .none,
            "transition": .keystroke(k("cmd+t")),
            "videoOnly": .toggle(on: k("shift+2"), off: k("shift+1")),
            "audioOnly": .toggle(on: k("shift+3"), off: k("shift+1")),
            "rippleDelete": .keystroke(k("delete")),
            "audioLevel": .keystroke(k("ctrl+opt+l")),
            "fullView": .keystroke(k("cmd+shift+f")),
            "snap": .keystroke(k("n")),
            "split": .keystroke(k("cmd+shift+b")),
            "liveOverwrite": .none,
            "escape": .keystroke(k("escape")),
            "cam1": .keystroke(k("1")), "cam2": .keystroke(k("2")), "cam3": .keystroke(k("3")),
            "cam4": .keystroke(k("4")), "cam5": .keystroke(k("5")), "cam6": .keystroke(k("6")),
            "cam7": .keystroke(k("7")), "cam8": .keystroke(k("8")), "cam9": .keystroke(k("9")),
            "stopPlay": .keystroke(k("space")),
        ],
        jog: .keys(WheelKeys(negative: k("left"), positive: k("right"), fastNegative: k("shift+left"), fastPositive: k("shift+right"))),
        scroll: .keys(WheelKeys(negative: k("up"), positive: k("down"))),
        shuttle: .jkl,
        framesPerRevolution: 60,
        scrollTicksPerStep: 24,
        holdWheel: [
            "trimIn": WheelKeys(negative: k(","), positive: k("."), fastNegative: k("shift+,"), fastPositive: k("shift+.")),
            "trimOut": WheelKeys(negative: k(","), positive: k("."), fastNegative: k("shift+,"), fastPositive: k("shift+.")),
            "roll": WheelKeys(negative: k(","), positive: k("."), fastNegative: k("shift+,"), fastPositive: k("shift+.")),
        ],
        releaseForResolve: true
    )

    static let logic = Profile(
        id: "logic",
        name: "Logic Pro",
        bundleIDs: KnownApps.logic,
        keys: [
            "smartInsert": .none,
            "append": .none,
            "rippleOverwrite": .none,
            "closeUp": .none,
            "placeOnTop": .none,
            "sourceOverwrite": .none,
            "markIn": .mackieChord(holding: .cycle, press: .rewind),
            "markOut": .mackieChord(holding: .cycle, press: .fastForward),
            "trimIn": .none,
            "trimOut": .none,
            "roll": .none,
            "slipSource": .none,
            "slipDestination": .none,
            "transitionDuration": .none,
            "cut": .keystroke(k("cmd+t")),
            "dissolve": .none,
            "smoothCut": .none,
            "source": .keystroke(k("y")),
            "timeline": .keystroke(k("x")),
            "shuttle": .wheelMode(.shuttle),
            "jog": .wheelMode(.jog),
            "scroll": .wheelMode(.scroll),
            "syncBin": .none,
            "transition": .none,
            "videoOnly": .none,
            "audioOnly": .mackie(.solo),
            "rippleDelete": .keystroke(k("delete")),
            "audioLevel": .keystroke(k("x")),
            "fullView": .keystroke(k("cmd+ctrl+f")),
            "snap": .mackie(.click),
            "split": .keystroke(k("cmd+t")),
            "liveOverwrite": .mackie(.record),
            "escape": .mackie(.cancel),
            "cam1": .mackie(.select1), "cam2": .mackie(.select2), "cam3": .mackie(.select3),
            "cam4": .mackie(.select4), "cam5": .mackie(.select5), "cam6": .mackie(.select6),
            "cam7": .mackie(.select7), "cam8": .mackie(.select8), "cam9": .none,
            "stopPlay": .mackiePlayStop,
        ],
        jog: .mackieJog,
        scroll: .keys(WheelKeys(negative: k("opt+,"), positive: k("opt+."))),
        shuttle: .mackieRate,
        framesPerRevolution: 96,
        scrollTicksPerStep: 24,
        holdWheel: [:],
        releaseForResolve: true
    )

    static let generic = Profile(
        id: "generic",
        name: "Generic",
        bundleIDs: [],
        keys: [
            "shuttle": .wheelMode(.shuttle),
            "jog": .wheelMode(.jog),
            "scroll": .wheelMode(.scroll),
            "stopPlay": .keystroke(k("space")),
            "escape": .keystroke(k("escape")),
        ],
        jog: .keys(WheelKeys(negative: k("left"), positive: k("right"))),
        scroll: .keys(WheelKeys(negative: k("up"), positive: k("down"))),
        shuttle: .jkl,
        framesPerRevolution: 60,
        scrollTicksPerStep: 24,
        holdWheel: [:],
        releaseForResolve: true
    )
}

/// Built-in profiles plus the user's saved overrides.
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile]

    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("Speed Editor Bridge/profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        profiles = DefaultProfiles.all.map { def in
            let url = Self.url(for: def.id, in: base.appendingPathComponent("Speed Editor Bridge/profiles", isDirectory: true))
            if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Profile.self, from: data) {
                return saved
            }
            return def
        }
    }

    private static func url(for id: String, in dir: URL) -> URL { dir.appendingPathComponent("\(id).json") }

    func profile(id: String) -> Profile? { profiles.first { $0.id == id } }

    func profile(forBundleID bundleID: String?) -> Profile? {
        guard let bundleID else { return nil }
        return profiles.first { $0.bundleIDs.contains(bundleID) }
    }

    func update(_ profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        if let data = try? Profile.encoder.encode(profile) {
            try? data.write(to: Self.url(for: profile.id, in: directory), options: .atomic)
        }
    }

    func setAction(_ action: Action, for key: SpeedEditorKey, in profileID: String) {
        guard var p = profile(id: profileID) else { return }
        p.keys[key.name] = action
        update(p)
    }

    func resetKey(_ key: SpeedEditorKey, in profileID: String) {
        guard var p = profile(id: profileID), let def = DefaultProfiles.profile(id: profileID) else { return }
        p.keys[key.name] = def.keys[key.name]
        update(p)
    }

    func resetProfile(_ profileID: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == profileID }), let def = DefaultProfiles.profile(id: profileID) else { return }
        profiles[idx] = def
        try? FileManager.default.removeItem(at: Self.url(for: profileID, in: directory))
    }

    func isDefault(_ key: SpeedEditorKey, in profileID: String) -> Bool {
        guard let p = profile(id: profileID), let def = DefaultProfiles.profile(id: profileID) else { return true }
        return p.action(for: key) == def.action(for: key)
    }

    func export(_ profileID: String, to url: URL) throws {
        guard let p = profile(id: profileID) else { return }
        try Profile.encoder.encode(p).write(to: url)
    }

    func importProfile(from url: URL) throws {
        let p = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: url))
        guard DefaultProfiles.profile(id: p.id) != nil else {
            throw NSError(domain: "SEB", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown profile id \(p.id)"])
        }
        update(p)
    }
}
