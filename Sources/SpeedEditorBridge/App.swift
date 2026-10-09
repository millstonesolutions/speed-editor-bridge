import SwiftUI

@main
struct SpeedEditorBridgeApp: App {
    @StateObject private var store: ProfileStore
    @StateObject private var engine: Engine

    init() {
        let store = ProfileStore()
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: Engine(store: store))
    }

    var body: some Scene {
        WindowGroup("Speed Editor Bridge") {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
    }
}
