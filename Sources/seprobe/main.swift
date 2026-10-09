import Foundation
import SpeedEditorKit

// Probe: open the Speed Editor, run the handshake, echo every event.
// SHTL / JOG / SCRL keys switch the wheel mode so each can be inspected.
// Usage: seprobe [--raw]

setvbuf(stdout, nil, _IOLBF, 0)
let raw = CommandLine.arguments.contains("--raw")

func stamp() -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date())
}

var accumulated: Int64 = 0
var minSeen: Int32 = 0
var maxSeen: Int32 = 0

func select(_ dev: SpeedEditorDevice, _ mode: JogMode, _ led: SpeedEditorJogLED, _ label: String) {
    do {
        try dev.setJogMode(mode)
        try dev.setJogLEDs(led)
        accumulated = 0; minSeen = 0; maxSeen = 0
        print("[\(stamp())] --- wheel mode now \(label) (\(mode)) ---")
    } catch {
        print("[\(stamp())] ERROR setting mode: \(error)")
    }
}

let monitor = SpeedEditorMonitor()
monitor.onConnect = { dev in
    print("[\(stamp())] device attached")
    dev.traceRaw = raw
    dev.onEvent = { event in
        switch event {
        case .keyDown(let k):
            print("[\(stamp())] DOWN \(k.legend)")
            switch k {
            case .shuttle: select(dev, .absoluteDeadZero, .shuttle, "SHTL absolute-deadzero")
            case .jog: select(dev, .relative, .jog, "JOG relative")
            case .scroll: select(dev, .relative2, .scroll, "SCRL relative2")
            case .fullView: select(dev, .absoluteContinuous, .shuttle, "FULL VIEW -> absolute-continuous")
            default: break
            }
        case .keyUp(let k): print("[\(stamp())] UP   \(k.legend)")
        case .jog(let m, let v):
            accumulated += Int64(v)
            minSeen = min(minSeen, v); maxSeen = max(maxSeen, v)
            print("[\(stamp())] JOG  mode=\(m) value=\(v) sum=\(accumulated) min=\(minSeen) max=\(maxSeen)")
        case .battery(let c, let l): print("[\(stamp())] BATT charging=\(c) level=\(l)")
        case .unknownKey(let c): print("[\(stamp())] UNKNOWN KEY 0x\(String(c, radix: 16))")
        case .raw(let id, let b): print("[\(stamp())] raw id=\(id) " + b.map { String(format: "%02x", $0) }.joined(separator: " "))
        }
    }
    do {
        try dev.open()
        print("[\(stamp())] handshake ok, device timeout \(Int(dev.authTimeout)) s")
        select(dev, .relative, .jog, "JOG relative")
        try dev.setLEDs([])
    } catch {
        print("[\(stamp())] ERROR \(error)")
    }
}
monitor.onDisconnect = { _ in print("[\(stamp())] device detached") }
monitor.start()

signal(SIGINT) { _ in
    print("\nbye")
    exit(0)
}
CFRunLoopRun()
