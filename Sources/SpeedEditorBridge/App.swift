import SwiftUI
import ServiceManagement

@main
struct SpeedEditorBridgeApp: App {
    @StateObject private var store: ProfileStore
    @StateObject private var engine: Engine
    @Environment(\.openWindow) private var openWindow

    init() {
        let store = ProfileStore()
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: Engine(store: store))
    }

    var body: some Scene {
        Window("Speed Editor Bridge", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            Text(menuStatus)
            Text("Profile: \(engine.activeProfile.name) · Wheel: \(engine.wheelMode.label)")
            Divider()
            Button("Open Mappings…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Picker("Profile", selection: Binding(
                get: { engine.lockedProfileID ?? "auto" },
                set: { engine.lockedProfileID = $0 == "auto" ? nil : $0 }
            )) {
                Text("Auto").tag("auto")
                ForEach(store.profiles) { Text($0.name).tag($0.id) }
            }
            Divider()
            LaunchAtLoginToggle()
            Divider()
            Button("Quit Speed Editor Bridge") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: engine.deviceOpen ? "dial.medium.fill" : "dial.medium")
        }
    }

    private var menuStatus: String {
        if !engine.deviceAttached { return "No Speed Editor attached" }
        if engine.releasedForResolve { return "Device released to DaVinci Resolve" }
        return engine.deviceOpen ? "Speed Editor connected" : "Speed Editor attached, not open"
    }
}

struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at Login", isOn: $enabled)
            .onChange(of: enabled) { _, on in
                do {
                    if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                } catch {
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}
