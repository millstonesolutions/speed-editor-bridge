import Foundation
import AppKit
import SpeedEditorKit

/// Ties the device to the active profile and the two output paths.
@MainActor
final class Engine: ObservableObject {
    @Published private(set) var deviceAttached = false
    @Published private(set) var deviceOpen = false
    @Published private(set) var releasedForResolve = false
    @Published private(set) var detectedProfileID = "generic"
    @Published var lockedProfileID: String? { didSet { applyProfileChange() } }
    @Published private(set) var wheelMode: WheelMode = .jog
    @Published private(set) var shuttleLevel = 0
    @Published private(set) var pressedKeys: Set<SpeedEditorKey> = []
    @Published private(set) var frontmostBundleID: String?
    @Published private(set) var accessibilityTrusted = KeySender.isTrusted
    @Published private(set) var log: [String] = []
    @Published private(set) var lastError: String?

    let store: ProfileStore
    let keys = KeySender()
    let mackie = MackieControl()

    private let monitor = SpeedEditorMonitor()
    private let apps = AppWatcher()
    private var device: SpeedEditorDevice?

    private var jogRemainder = 0.0
    private var scrollRemainder = 0.0
    private var holdRemainder = 0.0
    private var holdCandidates: [SpeedEditorKey] = []
    private var holdUsed: Set<SpeedEditorKey> = []
    private var toggles: Set<SpeedEditorKey> = []
    private var snapOn = true
    private var shuttleTimer: Timer?
    private var shuttleRate = 0.0
    private var shuttleAccumulator = 0.0
    private var trustTimer: Timer?

    /// Encoder ticks in one full turn of the wheel, measured on the device.
    static let ticksPerRevolution = 4600.0
    static let unitsPerTick = 360.0
    /// Shuttle position thresholds for speed levels 1...6 out of ±4096.
    static let shuttleThresholds: [Int32] = [300, 1100, 1900, 2700, 3400, 3900]

    var activeProfileID: String { lockedProfileID ?? detectedProfileID }
    var activeProfile: Profile { store.profile(id: activeProfileID) ?? DefaultProfiles.generic }

    init(store: ProfileStore) {
        self.store = store
        frontmostBundleID = apps.frontmostBundleID
        detectedProfileID = store.profile(forBundleID: apps.frontmostBundleID)?.id ?? "generic"

        monitor.onConnect = { [weak self] dev in
            Task { @MainActor in self?.attach(dev) }
        }
        monitor.onDisconnect = { [weak self] _ in
            Task { @MainActor in self?.detach() }
        }
        apps.onChange = { [weak self] bundleID in
            Task { @MainActor in self?.frontmostChanged(bundleID) }
        }
        mackie.onLog = { [weak self] msg in Task { @MainActor in self?.append(msg) } }
        mackie.onRecordState = { [weak self] _ in Task { @MainActor in self?.updateLEDs() } }

        monitor.start()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = KeySender.isTrusted
                if trusted != self.accessibilityTrusted { self.accessibilityTrusted = trusted }
            }
        }
    }

    func requestAccessibility() { KeySender.requestTrust() }

    // MARK: Device lifecycle

    private func attach(_ dev: SpeedEditorDevice) {
        device = dev
        deviceAttached = true
        dev.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        append("Speed Editor attached")
        if shouldRelease(for: frontmostBundleID) {
            releasedForResolve = true
            append("DaVinci Resolve is in front; leaving the device to it")
        } else {
            openDevice()
        }
    }

    private func detach() {
        device = nil
        deviceAttached = false
        deviceOpen = false
        pressedKeys = []
        stopShuttle()
        append("Speed Editor detached")
    }

    private func openDevice() {
        guard let dev = device, !deviceOpen else { return }
        do {
            try dev.open()
            deviceOpen = true
            releasedForResolve = false
            lastError = nil
            append("Handshake complete, device unlocked for \(Int(dev.authTimeout)) s at a time")
            applyWheelMode()
            updateLEDs()
        } catch {
            lastError = "Could not open the Speed Editor: \(error)"
            append(lastError!)
        }
    }

    private func releaseDevice() {
        guard deviceOpen else { return }
        stopShuttle()
        try? device?.setLEDs([])
        try? device?.setJogLEDs([])
        device?.close()
        deviceOpen = false
        releasedForResolve = true
        pressedKeys = []
        append("Released the device for DaVinci Resolve")
    }

    private func shouldRelease(for bundleID: String?) -> Bool {
        guard let bundleID, KnownApps.resolve.contains(bundleID) else { return false }
        return activeProfile.releaseForResolve
    }

    // MARK: App switching

    private func frontmostChanged(_ bundleID: String?) {
        frontmostBundleID = bundleID
        if let p = store.profile(forBundleID: bundleID) {
            if p.id != detectedProfileID {
                detectedProfileID = p.id
                append("Front app is \(p.name)")
                applyProfileChange()
            }
            if releasedForResolve, deviceAttached, !deviceOpen {
                append("\(p.name) is in front; taking the device back")
                openDevice()
            }
        }
        if shouldRelease(for: bundleID) {
            releaseDevice()
        }
    }

    private func applyProfileChange() {
        stopShuttle()
        shuttleLevel = 0
        holdCandidates = []
        holdUsed = []
        jogRemainder = 0; scrollRemainder = 0; holdRemainder = 0
        updateLEDs()
    }

    // MARK: Events

    private func handle(_ event: SpeedEditorEvent) {
        switch event {
        case .keyDown(let key):
            pressedKeys.insert(key)
            if activeProfile.holdWheel[key.name] != nil {
                holdCandidates.append(key)
            } else {
                perform(activeProfile.action(for: key), key: key)
            }
        case .keyUp(let key):
            pressedKeys.remove(key)
            if let idx = holdCandidates.firstIndex(of: key) {
                holdCandidates.remove(at: idx)
                if holdUsed.contains(key) {
                    holdUsed.remove(key)
                } else {
                    perform(activeProfile.action(for: key), key: key)
                }
            }
        case .jog(_, let value):
            wheel(value)
        case .battery, .unknownKey, .raw:
            break
        }
    }

    private func perform(_ action: Action, key: SpeedEditorKey) {
        let profile = activeProfile
        switch action {
        case .none:
            append("\(key.legend): no action in \(profile.name)")
            return
        case .keystroke(let combo):
            if key == .stopPlay { resetShuttleAfterTransport() }
            keys.press(combo)
            if key == .snap { snapOn.toggle(); updateLEDs() }
        case .sequence(let combos):
            keys.press(combos)
        case .mackie(let button):
            mackie.press(button)
        case .mackieChord(let holding, let press):
            mackie.chord(holding: holding, press: press)
        case .wheelMode(let mode):
            setWheelMode(mode)
        case .toggle(let on, let off):
            if toggles.contains(key) {
                toggles.remove(key)
                keys.press(off)
            } else {
                // Video-only and audio-only are mutually exclusive in both editors.
                if key == .videoOnly { toggles.remove(.audioOnly) }
                if key == .audioOnly { toggles.remove(.videoOnly) }
                toggles.insert(key)
                keys.press(on)
            }
            updateLEDs()
        case .mackiePlayStop:
            resetShuttleAfterTransport()
            mackie.playStop()
        }
        append("\(key.legend) → \(action.summary)")
    }

    private func resetShuttleAfterTransport() {
        guard wheelMode == .shuttle, shuttleLevel != 0 else { return }
        shuttleLevel = 0
        stopShuttle()
        try? device?.setJogMode(.absoluteDeadZero)   // re-centres the virtual position
    }

    // MARK: Wheel

    func setWheelMode(_ mode: WheelMode) {
        guard mode != wheelMode else { return }
        if wheelMode == .shuttle, shuttleLevel != 0 {
            if activeProfile.shuttle == .jkl { keys.press(KeyCombo("k")) }
            shuttleLevel = 0
            stopShuttle()
        }
        wheelMode = mode
        jogRemainder = 0; scrollRemainder = 0
        applyWheelMode()
        append("Wheel mode \(mode.label)")
    }

    private func applyWheelMode() {
        guard let dev = device, deviceOpen else { return }
        do {
            try dev.setJogMode(wheelMode == .shuttle ? .absoluteDeadZero : .relative)
            switch wheelMode {
            case .shuttle: try dev.setJogLEDs(.shuttle)
            case .jog: try dev.setJogLEDs(.jog)
            case .scroll: try dev.setJogLEDs(.scroll)
            }
        } catch {
            append("Wheel mode failed: \(error)")
        }
    }

    private func wheel(_ value: Int32) {
        let profile = activeProfile
        if let holdKey = holdCandidates.last, let keysForHold = profile.holdWheel[holdKey.name] {
            holdUsed.insert(holdKey)
            if wheelMode == .shuttle {
                // Shuttle positions are absolute; treat the position as a slow nudge rate.
                return
            }
            emit(keysForHold, value: Double(value), unitsPerStep: unitsPerFrame(profile), remainder: &holdRemainder)
            return
        }
        switch wheelMode {
        case .jog:
            switch profile.jog {
            case .keys(let wk): emit(wk, value: Double(value), unitsPerStep: unitsPerFrame(profile), remainder: &jogRemainder)
            case .mackieJog: emitMackie(value: Double(value), unitsPerStep: unitsPerFrame(profile), remainder: &jogRemainder)
            }
        case .scroll:
            let units = Double(profile.scrollTicksPerStep) * Self.unitsPerTick
            switch profile.scroll {
            case .keys(let wk): emit(wk, value: Double(value), unitsPerStep: units, remainder: &scrollRemainder)
            case .mackieJog: emitMackie(value: Double(value), unitsPerStep: units, remainder: &scrollRemainder)
            }
        case .shuttle:
            shuttle(position: value, style: profile.shuttle)
        }
    }

    private func unitsPerFrame(_ profile: Profile) -> Double {
        Self.ticksPerRevolution * Self.unitsPerTick / max(1, profile.framesPerRevolution)
    }

    private func steps(from value: Double, unitsPerStep: Double, remainder: inout Double) -> Int {
        remainder += value
        var n = Int(remainder / unitsPerStep)
        remainder -= Double(n) * unitsPerStep
        n = max(-40, min(40, n))
        return n
    }

    private func emit(_ wk: WheelKeys, value: Double, unitsPerStep: Double, remainder: inout Double) {
        let n = steps(from: value, unitsPerStep: unitsPerStep, remainder: &remainder)
        guard n != 0 else { return }
        let single = n > 0 ? wk.positive : wk.negative
        let fast = n > 0 ? wk.fastPositive : wk.fastNegative
        var count = abs(n)
        if let fast {
            while count >= 10 { keys.press(fast); count -= 10 }
        }
        for _ in 0..<count { keys.press(single) }
    }

    private func emitMackie(value: Double, unitsPerStep: Double, remainder: inout Double) {
        let n = steps(from: value, unitsPerStep: unitsPerStep, remainder: &remainder)
        mackie.jog(n)
    }

    // MARK: Shuttle

    private func level(for position: Int32) -> Int {
        let mag = abs(Int(position))
        var lvl = 0
        for (i, t) in Self.shuttleThresholds.enumerated() where mag >= Int(t) { lvl = i + 1 }
        return position < 0 ? -lvl : lvl
    }

    private func shuttle(position: Int32, style: ShuttleStyle) {
        let target = level(for: position)
        guard target != shuttleLevel else { return }
        switch style {
        case .jkl: applyJKL(from: shuttleLevel, to: target)
        case .mackieRate: applyMackieRate(target)
        }
        shuttleLevel = target
    }

    /// FCP speed levels: 0 stop, ±1 half speed, ±2 1x, ±3 2x, ±4 4x, ±5 8x, ±6 16x.
    private func applyJKL(from current: Int, to target: Int) {
        let k = KeyCombo("k")
        if target == 0 {
            keys.press(k)
            return
        }
        let forward = target > 0
        let dirKey = KeyCombo(forward ? "l" : "j")
        let sameDirection = (current > 0) == forward && current != 0
        let canExtend = sameDirection && abs(current) >= 2 && abs(target) > abs(current)
        if !canExtend {
            keys.press(k)
            if abs(target) == 1 {
                keys.pressWhileHolding(k, tap: dirKey)
                return
            }
            for _ in 0..<(abs(target) - 1) { keys.press(dirKey) }
        } else {
            for _ in 0..<(abs(target) - abs(current)) { keys.press(dirKey) }
        }
    }

    private func applyMackieRate(_ target: Int) {
        let rates: [Double] = [0, 2, 5, 12, 25, 50, 100]
        shuttleRate = (target < 0 ? -1 : 1) * rates[abs(target)]
        if shuttleRate == 0 {
            stopShuttle()
            return
        }
        if shuttleTimer == nil {
            shuttleAccumulator = 0
            shuttleTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.shuttleTick() }
            }
        }
    }

    private func shuttleTick() {
        shuttleAccumulator += shuttleRate * 0.02
        let n = Int(shuttleAccumulator)
        if n != 0 {
            shuttleAccumulator -= Double(n)
            mackie.jog(n)
        }
    }

    private func stopShuttle() {
        shuttleTimer?.invalidate()
        shuttleTimer = nil
        shuttleRate = 0
    }

    // MARK: LEDs and log

    private func updateLEDs() {
        guard let dev = device, deviceOpen else { return }
        var leds: SpeedEditorLED = []
        if toggles.contains(.videoOnly) { leds.insert(.videoOnly) }
        if toggles.contains(.audioOnly) { leds.insert(.audioOnly) }
        if snapOn, activeProfile.action(for: .snap).isAssigned { leds.insert(.snap) }
        if mackie.isRecording { leds.insert(.liveOverwrite) }
        try? dev.setLEDs(leds)
    }

    private func append(_ line: String) {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        log.append("\(f.string(from: Date()))  \(line)")
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }
}
