import Foundation
import SpeedEditorKit

// Probe: open the Speed Editor, run the handshake, echo every event.
// Usage: seprobe [--raw] [--mode relative|abs|relative2|deadzero]

setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments
let raw = args.contains("--raw")
var mode: JogMode = .relative
if let i = args.firstIndex(of: "--mode"), i + 1 < args.count {
    switch args[i + 1] {
    case "abs": mode = .absoluteContinuous
    case "relative2": mode = .relative2
    case "deadzero": mode = .absoluteDeadZero
    default: mode = .relative
    }
}

func stamp() -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date())
}

let monitor = SpeedEditorMonitor()
monitor.onConnect = { dev in
    print("[\(stamp())] device attached")
    dev.traceRaw = raw
    dev.onEvent = { event in
        switch event {
        case .keyDown(let k): print("[\(stamp())] DOWN \(k.legend) (0x\(String(k.rawValue, radix: 16)))")
        case .keyUp(let k): print("[\(stamp())] UP   \(k.legend)")
        case .jog(let m, let v): print("[\(stamp())] JOG  mode=\(m) value=\(v)")
        case .battery(let c, let l): print("[\(stamp())] BATT charging=\(c) level=\(l)")
        case .unknownKey(let c): print("[\(stamp())] UNKNOWN KEY 0x\(String(c, radix: 16))")
        case .raw(let id, let b): print("[\(stamp())] raw id=\(id) " + b.map { String(format: "%02x", $0) }.joined(separator: " "))
        }
    }
    do {
        try dev.open()
        print("[\(stamp())] handshake ok, device timeout \(Int(dev.authTimeout)) s")
        try dev.setJogMode(mode)
        try dev.setJogLEDs(mode == .relative ? .jog : (mode == .absoluteContinuous ? .shuttle : .scroll))
        try dev.setLEDs([.cut, .snap])
        print("[\(stamp())] jog mode \(mode); CUT and SNAP lit. Press keys / turn wheel. Ctrl-C to quit.")
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
