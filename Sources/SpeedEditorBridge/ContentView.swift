import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SpeedEditorKit

struct ContentView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProfileStore
    @State private var editingKey: SpeedEditorKey?
    @State private var showWheelSettings = false
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(alignment: .top, spacing: 0) {
                DeviceView(editingKey: $editingKey)
                    .padding(16)
                    .popover(item: $editingKey, arrowEdge: .bottom) { key in
                        KeyEditor(key: key, profileID: engine.activeProfileID)
                    }
                if showWheelSettings {
                    Divider()
                    WheelSettings().frame(width: 300)
                }
            }
            Divider()
            statusBar
            if showLog {
                Divider()
                logView
            }
        }
        .background(Color(white: 0.06))
        .preferredColorScheme(.dark)
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            statusDot
            Picker("Profile", selection: Binding(
                get: { engine.lockedProfileID ?? "auto" },
                set: { engine.lockedProfileID = $0 == "auto" ? nil : $0 }
            )) {
                Text("Auto (\(store.profile(id: engine.detectedProfileID)?.name ?? "Generic"))").tag("auto")
                Divider()
                ForEach(store.profiles) { Text($0.name).tag($0.id) }
            }
            .frame(maxWidth: 300)
            Spacer()
            if !engine.accessibilityTrusted {
                Button {
                    engine.requestAccessibility()
                } label: {
                    Label("Allow keystrokes (Accessibility)", systemImage: "exclamationmark.triangle")
                }
                .tint(Brand.blue)
                .help("Keystroke actions need Accessibility permission. Click, then enable Speed Editor Bridge in System Settings.")
            }
            Menu {
                Button("Reset \(engine.activeProfile.name) to defaults") { store.resetProfile(engine.activeProfileID) }
                Divider()
                Button("Export profile…") { exportProfile() }
                Button("Import profile…") { importProfile() }
            } label: { Label("Profile", systemImage: "slider.horizontal.3") }
            .frame(width: 110)
            Toggle(isOn: $showWheelSettings) { Label("Wheel", systemImage: "dial.medium") }.toggleStyle(.button)
            Toggle(isOn: $showLog) { Label("Log", systemImage: "list.bullet.rectangle") }.toggleStyle(.button)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var statusDot: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusText).font(.callout)
        }
    }

    private var statusColor: Color {
        if !engine.deviceAttached { return Brand.gray3 }
        if engine.releasedForResolve { return Brand.blue }
        return engine.deviceOpen ? Brand.cyan : Brand.gray3
    }

    private var statusText: String {
        if !engine.deviceAttached { return "No Speed Editor" }
        if engine.releasedForResolve { return "Released to Resolve" }
        return engine.deviceOpen ? "Connected" : "Attached, not open"
    }

    private var statusBar: some View {
        HStack {
            Text(engine.log.last ?? "Ready").font(.system(.callout, design: .monospaced)).lineLimit(1)
            Spacer()
            Text("Front: \(engine.frontmostBundleID ?? "—")").font(.caption).foregroundStyle(.secondary)
            Text("MIDI port: Speed Editor Bridge").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(engine.log.enumerated()), id: \.offset) { i, line in
                        Text(line).font(.system(size: 11, design: .monospaced)).id(i)
                    }
                }
                .padding(8)
            }
            .frame(height: 160)
            .onChange(of: engine.log.count) { _, n in proxy.scrollTo(n - 1) }
        }
    }

    private func exportProfile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(engine.activeProfileID).json"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.export(engine.activeProfileID, to: url)
        }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do { try store.importProfile(from: url) } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

/// Wheel behaviour for the active profile.
struct WheelSettings: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProfileStore

    var body: some View {
        let profile = engine.activeProfile
        Form {
            Section("Wheel in \(profile.name)") {
                LabeledContent("Mode now", value: engine.wheelMode.label)
                Picker("Shuttle", selection: Binding(get: { profile.shuttle }, set: { v in var p = profile; p.shuttle = v; store.update(p) })) {
                    ForEach(ShuttleStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Stepper(value: Binding(get: { profile.framesPerRevolution }, set: { v in var p = profile; p.framesPerRevolution = max(6, v); store.update(p) }), step: 6) {
                    LabeledContent(profile.jog == .mackieJog ? "Jog ticks / turn" : "Frames / turn", value: "\(Int(profile.framesPerRevolution))")
                }
                Stepper(value: Binding(get: { profile.scrollTicksPerStep }, set: { v in var p = profile; p.scrollTicksPerStep = max(2, v); store.update(p) }), step: 2) {
                    LabeledContent("Scroll step (ticks)", value: "\(profile.scrollTicksPerStep)")
                }
            }
            Section("Jog keys") {
                WheelKeysEditor(output: Binding(get: { profile.jog }, set: { v in var p = profile; p.jog = v; store.update(p) }))
            }
            Section("Scroll keys") {
                WheelKeysEditor(output: Binding(get: { profile.scroll }, set: { v in var p = profile; p.scroll = v; store.update(p) }))
            }
            if !profile.holdWheel.isEmpty {
                Section("Hold a key and turn") {
                    ForEach(profile.holdWheel.keys.sorted(), id: \.self) { name in
                        if let key = SpeedEditorKey(name: name), let wk = profile.holdWheel[name] {
                            LabeledContent(key.legend, value: wk.summary)
                        }
                    }
                }
            }
            Section {
                Toggle("Release device when Resolve is in front", isOn: Binding(get: { profile.releaseForResolve }, set: { v in var p = profile; p.releaseForResolve = v; store.update(p) }))
            }
        }
        .formStyle(.grouped)
    }
}

struct WheelKeysEditor: View {
    @Binding var output: WheelOutput

    var body: some View {
        Picker("Output", selection: Binding<String>(
            get: { if case .mackieJog = output { return "mackie" } else { return "keys" } },
            set: { (v: String) in
                if v == "mackie" { output = .mackieJog }
                else if case .mackieJog = output { output = .keys(WheelKeys(negative: KeyCombo("left"), positive: KeyCombo("right"))) }
            }
        )) {
            Text("Keystrokes").tag("keys")
            Text("Mackie jog wheel").tag("mackie")
        }
        if case .keys(let wk) = output {
            comboField("Back", wk.negative) { c in if let c { var w = wk; w.negative = c; output = .keys(w) } }
            comboField("Forward", wk.positive) { c in if let c { var w = wk; w.positive = c; output = .keys(w) } }
            comboField("Back ×10", wk.fastNegative) { c in var w = wk; w.fastNegative = c; output = .keys(w) }
            comboField("Forward ×10", wk.fastPositive) { c in var w = wk; w.fastPositive = c; output = .keys(w) }
        }
    }

    private func comboField(_ label: String, _ value: KeyCombo?, set: @escaping (KeyCombo?) -> Void) -> some View {
        ComboTextField(label: label, text: value?.canonical ?? "") { text in
            if text.isEmpty { set(nil) } else if let c = KeyCombo(parsing: text) { set(c) }
        }
    }
}

struct ComboTextField: View {
    let label: String
    @State var text: String
    let commit: (String) -> Void

    var body: some View {
        TextField(label, text: $text)
            .onSubmit { commit(text) }
            .onChange(of: text) { _, new in if KeyCombo(parsing: new) != nil || new.isEmpty { commit(new) } }
    }
}
