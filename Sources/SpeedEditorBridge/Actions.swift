import Foundation
import Carbon.HIToolbox
import SpeedEditorKit

/// A keyboard chord, stored as a key name plus modifiers.
struct KeyCombo: Codable, Hashable, CustomStringConvertible {
    var key: String
    var command = false
    var shift = false
    var option = false
    var control = false

    init(_ key: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.key = key.lowercased()
        self.command = command; self.shift = shift; self.option = option; self.control = control
    }

    /// Parse "cmd+shift+b", "left", "shift+delete".
    init?(parsing text: String) {
        var combo = KeyCombo("")
        for part in text.lowercased().split(separator: "+").map(String.init) {
            switch part {
            case "cmd", "command", "⌘": combo.command = true
            case "shift", "⇧": combo.shift = true
            case "opt", "option", "alt", "⌥": combo.option = true
            case "ctrl", "control", "⌃": combo.control = true
            default: combo.key = part
            }
        }
        guard KeyCodes.code(for: combo.key) != nil else { return nil }
        self = combo
    }

    var description: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        return s + KeyCodes.display(key)
    }
}

/// US-layout virtual key codes.
enum KeyCodes {
    static let table: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
        "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31,
        "u": 32, "[": 33, "i": 34, "p": 35, "return": 36, "l": 37, "j": 38, "'": 39, "k": 40,
        ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49,
        "`": 50, "delete": 51, "escape": 53, "forwarddelete": 117, "home": 115, "end": 119,
        "pageup": 116, "pagedown": 121, "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "comma": 43, "period": 47, "semicolon": 41, "quote": 39, "slash": 44, "backslash": 42,
        "minus": 27, "equals": 24, "grave": 50, "esc": 53, "enter": 36, "backspace": 51,
    ]
    static let reverse: [CGKeyCode: String] = {
        var r: [CGKeyCode: String] = [:]
        for (name, code) in table where r[code] == nil || name.count == 1 { r[code] = name }
        // prefer the canonical spellings
        for (name, code) in table where ["escape", "delete", "return", "space", "tab", "left", "right", "up", "down"].contains(name) { r[code] = name }
        return r
    }()

    static func code(for name: String) -> CGKeyCode? { table[name.lowercased()] }
    static func name(for code: CGKeyCode) -> String? { reverse[code] }

    static func display(_ key: String) -> String {
        switch key {
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "space": return "Space"
        case "delete", "backspace": return "⌫"
        case "forwarddelete": return "⌦"
        case "escape", "esc": return "Esc"
        case "return", "enter": return "↩"
        case "tab": return "⇥"
        case "comma": return ","
        case "period": return "."
        case "semicolon": return ";"
        case "quote": return "'"
        default: return key.uppercased()
        }
    }
}

/// Mackie Control switches, by note number.
enum MackieButton: UInt8, Codable, CaseIterable, Identifiable {
    case rewind = 0x5b, fastForward = 0x5c, stop = 0x5d, play = 0x5e, record = 0x5f
    case cycle = 0x56, drop = 0x57, replace = 0x58, click = 0x59, solo = 0x5a
    case marker = 0x54, nudge = 0x55
    case save = 0x50, undo = 0x51, cancel = 0x52, enter = 0x53
    case shift = 0x46, option = 0x47, control = 0x48, alt = 0x49
    case up = 0x60, down = 0x61, left = 0x62, right = 0x63, zoom = 0x64, scrub = 0x65
    case bankLeft = 0x2e, bankRight = 0x2f, channelLeft = 0x30, channelRight = 0x31, flip = 0x32, globalView = 0x33
    case nameValue = 0x34, smpteBeats = 0x35
    case f1 = 0x36, f2 = 0x37, f3 = 0x38, f4 = 0x39, f5 = 0x3a, f6 = 0x3b, f7 = 0x3c, f8 = 0x3d
    case select1 = 0x18, select2 = 0x19, select3 = 0x1a, select4 = 0x1b, select5 = 0x1c, select6 = 0x1d, select7 = 0x1e, select8 = 0x1f
    case mute1 = 0x10, solo1 = 0x08, recArm1 = 0x00

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .rewind: return "Rewind"
        case .fastForward: return "Fast Fwd"
        case .stop: return "Stop"
        case .play: return "Play"
        case .record: return "Record"
        case .cycle: return "Cycle"
        case .drop: return "Drop"
        case .replace: return "Replace"
        case .click: return "Click"
        case .solo: return "Solo"
        case .marker: return "Marker"
        case .nudge: return "Nudge"
        case .save: return "Save"
        case .undo: return "Undo"
        case .cancel: return "Cancel"
        case .enter: return "Enter"
        case .shift: return "Shift"
        case .option: return "Option"
        case .control: return "Control"
        case .alt: return "Alt"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .zoom: return "Zoom"
        case .scrub: return "Scrub"
        case .bankLeft: return "Bank ◀"
        case .bankRight: return "Bank ▶"
        case .channelLeft: return "Channel ◀"
        case .channelRight: return "Channel ▶"
        case .flip: return "Flip"
        case .globalView: return "Global View"
        case .nameValue: return "Name/Value"
        case .smpteBeats: return "SMPTE/Beats"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .select1: return "Select 1"
        case .select2: return "Select 2"
        case .select3: return "Select 3"
        case .select4: return "Select 4"
        case .select5: return "Select 5"
        case .select6: return "Select 6"
        case .select7: return "Select 7"
        case .select8: return "Select 8"
        case .mute1: return "Mute 1"
        case .solo1: return "Solo 1"
        case .recArm1: return "Rec Arm 1"
        }
    }
}

enum WheelMode: String, Codable, CaseIterable {
    case shuttle, jog, scroll
    var label: String {
        switch self {
        case .shuttle: return "SHTL"
        case .jog: return "JOG"
        case .scroll: return "SCRL"
        }
    }
}

/// What a key does when pressed.
indirect enum Action: Codable, Hashable {
    case none
    case keystroke(KeyCombo)
    case sequence([KeyCombo])
    case mackie(MackieButton)
    /// Hold `holding` while tapping `press` (Mackie chords like Cycle+Rewind).
    case mackieChord(holding: MackieButton, press: MackieButton)
    case wheelMode(WheelMode)
    /// Alternates between two keystrokes; the LED shows the state.
    case toggle(on: KeyCombo, off: KeyCombo)
    /// Play/stop that tracks transport state through Mackie feedback.
    case mackiePlayStop

    var summary: String {
        switch self {
        case .none: return "—"
        case .keystroke(let k): return k.description
        case .sequence(let ks): return ks.map(\.description).joined(separator: " ")
        case .mackie(let b): return "MCU \(b.label)"
        case .mackieChord(let h, let p): return "MCU \(h.label)+\(p.label)"
        case .wheelMode(let m): return "Wheel: \(m.label)"
        case .toggle(let on, let off): return "\(on) / \(off)"
        case .mackiePlayStop: return "MCU Play/Stop"
        }
    }

    var isAssigned: Bool { if case .none = self { return false } else { return true } }
}

/// Keys the wheel sends in a relative mode.
struct WheelKeys: Codable, Hashable {
    var negative: KeyCombo
    var positive: KeyCombo
    var fastNegative: KeyCombo?
    var fastPositive: KeyCombo?

    var summary: String {
        var s = "\(negative) / \(positive)"
        if let fn = fastNegative, let fp = fastPositive { s += "  (×10: \(fn) / \(fp))" }
        return s
    }
}

enum ShuttleStyle: String, Codable, CaseIterable {
    /// Drive J / K / L speed levels.
    case jkl
    /// Emit Mackie jog ticks at a rate set by the wheel position.
    case mackieRate
    var label: String { self == .jkl ? "J / K / L keys" : "Mackie jog at speed" }
}

enum WheelOutput: Codable, Hashable {
    case keys(WheelKeys)
    case mackieJog
    var summary: String {
        switch self {
        case .keys(let k): return k.summary
        case .mackieJog: return "MCU jog wheel"
        }
    }
}
