import SwiftUI
import AppKit
import SpeedEditorKit

/// Popover for changing what one key does in the active profile.
struct KeyEditor: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProfileStore
    let key: SpeedEditorKey
    let profileID: String
    @Environment(\.dismiss) private var dismiss

    enum Kind: String, CaseIterable, Identifiable {
        case none = "Nothing", keystroke = "Keystroke", mackie = "Mackie button", chord = "Mackie chord", wheel = "Wheel mode", toggle = "Toggle (two keystrokes)", playStop = "Mackie play/stop"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .none
    @State private var combo = KeyCombo("space")
    @State private var comboText = ""
    @State private var offCombo = KeyCombo("space")
    @State private var offText = ""
    @State private var mackie: MackieButton = .play
    @State private var chordHold: MackieButton = .cycle
    @State private var chordPress: MackieButton = .rewind
    @State private var wheel: WheelMode = .jog
    @State private var recording = false
    @State private var recordingOff = false
    @State private var parseError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(key.legend).font(.title3.bold())
                Spacer()
                Text(store.profile(id: profileID)?.name ?? "").foregroundStyle(.secondary)
            }
            Picker("Action", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            switch kind {
            case .none:
                Text("This key does nothing in this profile.").foregroundStyle(.secondary)
            case .keystroke:
                shortcutRow(text: $comboText, combo: $combo, recording: $recording, label: "Shortcut")
            case .toggle:
                shortcutRow(text: $comboText, combo: $combo, recording: $recording, label: "On")
                shortcutRow(text: $offText, combo: $offCombo, recording: $recordingOff, label: "Off")
            case .mackie:
                Picker("Button", selection: $mackie) { ForEach(MackieButton.allCases) { Text($0.label).tag($0) } }
            case .chord:
                Picker("Hold", selection: $chordHold) { ForEach(MackieButton.allCases) { Text($0.label).tag($0) } }
                Picker("Press", selection: $chordPress) { ForEach(MackieButton.allCases) { Text($0.label).tag($0) } }
            case .wheel:
                Picker("Mode", selection: $wheel) { ForEach(WheelMode.allCases, id: \.self) { Text($0.label).tag($0) } }
            case .playStop:
                Text("Sends Mackie Play or Stop depending on Logic's transport state.").foregroundStyle(.secondary)
            }
            if parseError {
                Text("That shortcut didn't parse. Use names like cmd+shift+b, left, shift+delete.").font(.caption).foregroundStyle(Brand.blue)
            }
            Divider()
            HStack {
                Button("Reset to default") {
                    store.resetKey(key, in: profileID)
                    load()
                }
                .disabled(store.isDefault(key, in: profileID))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear(perform: load)
    }

    private func shortcutRow(text: Binding<String>, combo: Binding<KeyCombo>, recording: Binding<Bool>, label: String) -> some View {
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            TextField("cmd+shift+b", text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { _, new in
                    if let c = KeyCombo(parsing: new) { combo.wrappedValue = c; parseError = false } else { parseError = !new.isEmpty }
                }
            ShortcutRecorderButton(recording: recording) { captured in
                combo.wrappedValue = captured
                text.wrappedValue = captured.canonical
                parseError = false
            }
            Text(combo.wrappedValue.description).font(.title3.monospaced()).frame(minWidth: 60)
        }
    }

    private func load() {
        let action = store.profile(id: profileID)?.action(for: key) ?? .none
        switch action {
        case .none: kind = .none
        case .keystroke(let c): kind = .keystroke; combo = c; comboText = c.canonical
        case .sequence(let cs): kind = .keystroke; combo = cs.first ?? KeyCombo("space"); comboText = combo.canonical
        case .mackie(let b): kind = .mackie; mackie = b
        case .mackieChord(let h, let p): kind = .chord; chordHold = h; chordPress = p
        case .wheelMode(let m): kind = .wheel; wheel = m
        case .toggle(let on, let off): kind = .toggle; combo = on; comboText = on.canonical; offCombo = off; offText = off.canonical
        case .mackiePlayStop: kind = .playStop
        }
    }

    private func save() {
        let action: Action
        switch kind {
        case .none: action = .none
        case .keystroke: action = .keystroke(combo)
        case .toggle: action = .toggle(on: combo, off: offCombo)
        case .mackie: action = .mackie(mackie)
        case .chord: action = .mackieChord(holding: chordHold, press: chordPress)
        case .wheel: action = .wheelMode(wheel)
        case .playStop: action = .mackiePlayStop
        }
        store.setAction(action, for: key, in: profileID)
        dismiss()
    }
}

extension KeyCombo {
    /// Text form that round-trips through `init(parsing:)`.
    var canonical: String {
        var parts: [String] = []
        if control { parts.append("ctrl") }
        if option { parts.append("opt") }
        if shift { parts.append("shift") }
        if command { parts.append("cmd") }
        parts.append(key)
        return parts.joined(separator: "+")
    }
}

/// Click, then press the shortcut you want.
struct ShortcutRecorderButton: View {
    @Binding var recording: Bool
    let onCapture: (KeyCombo) -> Void
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Press keys…" : "Record") {
            if recording { stop() } else { start() }
        }
        .tint(recording ? Brand.cyan : nil)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard let name = KeyCodes.name(for: CGKeyCode(event.keyCode)) else { return nil }
            let f = event.modifierFlags
            let combo = KeyCombo(name, command: f.contains(.command), shift: f.contains(.shift), option: f.contains(.option), control: f.contains(.control))
            onCapture(combo)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
