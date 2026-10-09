import Foundation

/// Physical keys on the Speed Editor, as reported in the key input report.
public enum SpeedEditorKey: UInt16, CaseIterable, Codable, Hashable, Sendable {
    case smartInsert = 0x01
    case append = 0x02
    case rippleOverwrite = 0x03
    case closeUp = 0x04
    case placeOnTop = 0x05
    case sourceOverwrite = 0x06
    case markIn = 0x07
    case markOut = 0x08
    case trimIn = 0x09
    case trimOut = 0x0a
    case roll = 0x0b
    case slipSource = 0x0c
    case slipDestination = 0x0d
    case transitionDuration = 0x0e
    case cut = 0x0f
    case dissolve = 0x10
    case smoothCut = 0x11
    case source = 0x1a
    case timeline = 0x1b
    case shuttle = 0x1c
    case jog = 0x1d
    case scroll = 0x1e
    case syncBin = 0x1f
    case transition = 0x22
    case videoOnly = 0x25
    case audioOnly = 0x26
    case rippleDelete = 0x2b
    case audioLevel = 0x2c
    case fullView = 0x2d
    case snap = 0x2e
    case split = 0x2f
    case liveOverwrite = 0x30
    case escape = 0x31
    case cam1 = 0x33
    case cam2 = 0x34
    case cam3 = 0x35
    case cam4 = 0x36
    case cam5 = 0x37
    case cam6 = 0x38
    case cam7 = 0x39
    case cam8 = 0x3a
    case cam9 = 0x3b
    case stopPlay = 0x3c

    /// The legend printed on the key cap.
    public var legend: String {
        switch self {
        case .smartInsert: return "SMART INSRT"
        case .append: return "APPND"
        case .rippleOverwrite: return "RIPL O/WR"
        case .closeUp: return "CLOSE UP"
        case .placeOnTop: return "PLACE ON TOP"
        case .sourceOverwrite: return "SRC O/WR"
        case .markIn: return "IN"
        case .markOut: return "OUT"
        case .trimIn: return "TRIM IN"
        case .trimOut: return "TRIM OUT"
        case .roll: return "ROLL"
        case .slipSource: return "SLIP SRC"
        case .slipDestination: return "SLIP DEST"
        case .transitionDuration: return "TRANS DUR"
        case .cut: return "CUT"
        case .dissolve: return "DIS"
        case .smoothCut: return "SMTH CUT"
        case .source: return "SOURCE"
        case .timeline: return "TIMELINE"
        case .shuttle: return "SHTL"
        case .jog: return "JOG"
        case .scroll: return "SCRL"
        case .syncBin: return "SYNC BIN"
        case .transition: return "TRANS"
        case .videoOnly: return "VIDEO ONLY"
        case .audioOnly: return "AUDIO ONLY"
        case .rippleDelete: return "RIPL DEL"
        case .audioLevel: return "AUDIO LEVEL"
        case .fullView: return "FULL VIEW"
        case .snap: return "SNAP"
        case .split: return "SPLIT"
        case .liveOverwrite: return "LIVE O/WR"
        case .escape: return "ESC"
        case .cam1: return "CAM 1"
        case .cam2: return "CAM 2"
        case .cam3: return "CAM 3"
        case .cam4: return "CAM 4"
        case .cam5: return "CAM 5"
        case .cam6: return "CAM 6"
        case .cam7: return "CAM 7"
        case .cam8: return "CAM 8"
        case .cam9: return "CAM 9"
        case .stopPlay: return "STOP/PLAY"
        }
    }

    /// LED behind this key, if it has one.
    public var led: SpeedEditorLED? {
        switch self {
        case .closeUp: return .closeUp
        case .cut: return .cut
        case .dissolve: return .dissolve
        case .smoothCut: return .smoothCut
        case .transition: return .transition
        case .snap: return .snap
        case .cam1: return .cam1
        case .cam2: return .cam2
        case .cam3: return .cam3
        case .cam4: return .cam4
        case .cam5: return .cam5
        case .cam6: return .cam6
        case .cam7: return .cam7
        case .cam8: return .cam8
        case .cam9: return .cam9
        case .liveOverwrite: return .liveOverwrite
        case .videoOnly: return .videoOnly
        case .audioOnly: return .audioOnly
        default: return nil
        }
    }
}

/// Backlit keys, as bits in the main LED output report.
public struct SpeedEditorLED: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let closeUp = SpeedEditorLED(rawValue: 1 << 0)
    public static let cut = SpeedEditorLED(rawValue: 1 << 1)
    public static let dissolve = SpeedEditorLED(rawValue: 1 << 2)
    public static let smoothCut = SpeedEditorLED(rawValue: 1 << 3)
    public static let transition = SpeedEditorLED(rawValue: 1 << 4)
    public static let snap = SpeedEditorLED(rawValue: 1 << 5)
    public static let cam7 = SpeedEditorLED(rawValue: 1 << 6)
    public static let cam8 = SpeedEditorLED(rawValue: 1 << 7)
    public static let cam9 = SpeedEditorLED(rawValue: 1 << 8)
    public static let liveOverwrite = SpeedEditorLED(rawValue: 1 << 9)
    public static let cam4 = SpeedEditorLED(rawValue: 1 << 10)
    public static let cam5 = SpeedEditorLED(rawValue: 1 << 11)
    public static let cam6 = SpeedEditorLED(rawValue: 1 << 12)
    public static let videoOnly = SpeedEditorLED(rawValue: 1 << 13)
    public static let cam1 = SpeedEditorLED(rawValue: 1 << 14)
    public static let cam2 = SpeedEditorLED(rawValue: 1 << 15)
    public static let cam3 = SpeedEditorLED(rawValue: 1 << 16)
    public static let audioOnly = SpeedEditorLED(rawValue: 1 << 17)
    public static let all = SpeedEditorLED(rawValue: (1 << 18) - 1)
}

/// The three wheel-mode indicator LEDs.
public struct SpeedEditorJogLED: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let jog = SpeedEditorJogLED(rawValue: 1 << 0)
    public static let shuttle = SpeedEditorJogLED(rawValue: 1 << 1)
    public static let scroll = SpeedEditorJogLED(rawValue: 1 << 2)
}

/// How the wheel reports motion.
public enum JogMode: UInt8, Codable, Sendable {
    /// Relative deltas, detented feel.
    case relative = 0
    /// Absolute position, spring returns to centre, continuous.
    case absoluteContinuous = 1
    /// Relative deltas, second variant.
    case relative2 = 2
    /// Absolute position with a dead zone at centre.
    case absoluteDeadZero = 3
}
