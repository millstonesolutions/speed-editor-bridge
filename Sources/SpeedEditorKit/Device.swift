import Foundation
import IOKit
import IOKit.hid

public enum SpeedEditorError: Error, CustomStringConvertible {
    case openFailed(IOReturn)
    case reportFailed(String, IOReturn)
    case badHandshake(step: Int, got: [UInt8])

    public var description: String {
        switch self {
        case .openFailed(let r): return "open failed (0x\(String(r, radix: 16)))"
        case .reportFailed(let what, let r): return "\(what) failed (0x\(String(r, radix: 16)))"
        case .badHandshake(let step, let got):
            return "handshake step \(step) got " + got.map { String(format: "%02x", $0) }.joined(separator: " ")
        }
    }
}

/// Something the device told us.
public enum SpeedEditorEvent: Sendable {
    case keyDown(SpeedEditorKey)
    case keyUp(SpeedEditorKey)
    /// Wheel motion. `value` is a delta in relative modes and a position in absolute modes.
    case jog(mode: JogMode, value: Int32)
    case battery(charging: Bool, level: Int)
    case unknownKey(UInt16)
    case raw(reportID: UInt32, bytes: [UInt8])
}

public let speedEditorVendorID = 0x1edb
public let speedEditorProductID = 0xda0e

/// One connected Speed Editor. All calls must be made on the thread that owns
/// the run loop the device is scheduled on (the main thread by default).
public final class SpeedEditorDevice {
    public let hid: IOHIDDevice
    public var onEvent: ((SpeedEditorEvent) -> Void)?
    /// Echo every input report, for debugging.
    public var traceRaw = false

    public private(set) var pressed: Set<SpeedEditorKey> = []
    public private(set) var authTimeout: TimeInterval = 0
    private var reauthTimer: Timer?
    private var inputBuffer: UnsafeMutablePointer<UInt8>
    private let inputBufferSize = 64
    private var isOpen = false

    init(hid: IOHIDDevice) {
        self.hid = hid
        inputBuffer = .allocate(capacity: inputBufferSize)
    }

    deinit {
        close()
        inputBuffer.deallocate()
    }

    /// Open, authenticate, and start delivering events.
    public func open() throws {
        let r = IOHIDDeviceOpen(hid, IOOptionBits(kIOHIDOptionsTypeNone))
        guard r == kIOReturnSuccess else { throw SpeedEditorError.openFailed(r) }
        isOpen = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(hid, inputBuffer, inputBufferSize, { context, _, _, _, reportID, report, length in
            guard let context else { return }
            let me = Unmanaged<SpeedEditorDevice>.fromOpaque(context).takeUnretainedValue()
            me.handleInput(reportID: reportID, bytes: Array(UnsafeBufferPointer(start: report, count: length)))
        }, context)
        IOHIDDeviceScheduleWithRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        try authenticate()
    }

    public func close() {
        guard isOpen else { return }
        reauthTimer?.invalidate()
        reauthTimer = nil
        IOHIDDeviceRegisterInputReportCallback(hid, inputBuffer, inputBufferSize, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(hid, IOOptionBits(kIOHIDOptionsTypeNone))
        isOpen = false
    }

    // MARK: Handshake

    /// Run the challenge-response exchange. The device answers with a timeout
    /// in seconds after which it must be repeated; a timer handles that.
    public func authenticate() throws {
        try setFeature([0x06, 0x00, 0, 0, 0, 0, 0, 0, 0, 0])

        let challengeReport = try getFeature(reportID: 6, length: 10)
        guard challengeReport.count == 10, challengeReport[0] == 0x06, challengeReport[1] == 0x00 else {
            throw SpeedEditorError.badHandshake(step: 1, got: challengeReport)
        }
        let challenge = challengeReport[2..<10].enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << (8 * UInt64(pair.offset)))
        }

        // Our challenge to the device. We do not verify its answer, so zeros are fine.
        try setFeature([0x06, 0x01, 0, 0, 0, 0, 0, 0, 0, 0])
        let theirResponse = try getFeature(reportID: 6, length: 10)
        guard theirResponse.count == 10, theirResponse[0] == 0x06, theirResponse[1] == 0x02 else {
            throw SpeedEditorError.badHandshake(step: 2, got: theirResponse)
        }

        let response = SpeedEditorAuth.response(to: challenge)
        var reply: [UInt8] = [0x06, 0x03]
        for i in 0..<8 { reply.append(UInt8((response >> (8 * UInt64(i))) & 0xff)) }
        try setFeature(reply)

        let status = try getFeature(reportID: 6, length: 10)
        guard status.count == 10, status[0] == 0x06, status[1] == 0x04 else {
            throw SpeedEditorError.badHandshake(step: 3, got: status)
        }
        authTimeout = TimeInterval(UInt16(status[2]) | (UInt16(status[3]) << 8))
        scheduleReauth()
    }

    private func scheduleReauth() {
        reauthTimer?.invalidate()
        let interval = max(30, authTimeout / 2)
        reauthTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, self.isOpen else { return }
            do { try self.authenticate() } catch { self.scheduleReauth() }
        }
    }

    // MARK: Output

    public func setLEDs(_ leds: SpeedEditorLED) throws {
        let v = leds.rawValue
        try setOutput([0x02, UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)])
    }

    public func setJogLEDs(_ leds: SpeedEditorJogLED) throws {
        try setOutput([0x04, leds.rawValue])
    }

    public func setJogMode(_ mode: JogMode) throws {
        try setOutput([0x03, mode.rawValue, 0, 0, 0, 0, 0xff])
    }

    // MARK: Input

    private func handleInput(reportID: UInt32, bytes: [UInt8]) {
        if traceRaw { onEvent?(.raw(reportID: reportID, bytes: bytes)) }
        // IOKit hands us the report with its ID in byte 0 for devices that use IDs.
        let body: [UInt8] = (bytes.first.map { UInt32($0) } == reportID) ? Array(bytes.dropFirst()) : bytes

        switch reportID {
        case 4:
            var now: Set<SpeedEditorKey> = []
            var i = 0
            while i + 1 < body.count && i < 12 {
                let code = UInt16(body[i]) | (UInt16(body[i + 1]) << 8)
                if code != 0 {
                    if let key = SpeedEditorKey(rawValue: code) { now.insert(key) } else { onEvent?(.unknownKey(code)) }
                }
                i += 2
            }
            for key in now.subtracting(pressed) { onEvent?(.keyDown(key)) }
            for key in pressed.subtracting(now) { onEvent?(.keyUp(key)) }
            pressed = now
        case 3:
            guard body.count >= 5 else { return }
            let mode = JogMode(rawValue: body[0]) ?? .relative
            let raw = UInt32(body[1]) | (UInt32(body[2]) << 8) | (UInt32(body[3]) << 16) | (UInt32(body[4]) << 24)
            onEvent?(.jog(mode: mode, value: Int32(bitPattern: raw)))
        case 7:
            guard body.count >= 2 else { return }
            onEvent?(.battery(charging: body[0] != 0, level: Int(body[1])))
        default:
            break
        }
    }

    // MARK: Report plumbing

    private func setFeature(_ bytes: [UInt8]) throws {
        let r = bytes.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(hid, kIOHIDReportTypeFeature, CFIndex(bytes[0]), $0.baseAddress!, bytes.count)
        }
        guard r == kIOReturnSuccess else { throw SpeedEditorError.reportFailed("set feature \(bytes[0])", r) }
    }

    private func getFeature(reportID: UInt8, length: Int) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: length)
        buf[0] = reportID
        var len = CFIndex(length)
        let r = buf.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(hid, kIOHIDReportTypeFeature, CFIndex(reportID), $0.baseAddress!, &len)
        }
        guard r == kIOReturnSuccess else { throw SpeedEditorError.reportFailed("get feature \(reportID)", r) }
        return Array(buf.prefix(len))
    }

    private func setOutput(_ bytes: [UInt8]) throws {
        let r = bytes.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(hid, kIOHIDReportTypeOutput, CFIndex(bytes[0]), $0.baseAddress!, bytes.count)
        }
        guard r == kIOReturnSuccess else { throw SpeedEditorError.reportFailed("set output \(bytes[0])", r) }
    }
}

/// Watches for Speed Editors arriving and leaving.
public final class SpeedEditorMonitor {
    public var onConnect: ((SpeedEditorDevice) -> Void)?
    public var onDisconnect: ((SpeedEditorDevice) -> Void)?
    public private(set) var devices: [SpeedEditorDevice] = []
    private let manager: IOHIDManager

    public init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: speedEditorVendorID,
            kIOHIDProductIDKey as String: speedEditorProductID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, hid in
            guard let context else { return }
            let me = Unmanaged<SpeedEditorMonitor>.fromOpaque(context).takeUnretainedValue()
            let dev = SpeedEditorDevice(hid: hid)
            me.devices.append(dev)
            me.onConnect?(dev)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, hid in
            guard let context else { return }
            let me = Unmanaged<SpeedEditorMonitor>.fromOpaque(context).takeUnretainedValue()
            if let idx = me.devices.firstIndex(where: { $0.hid == hid }) {
                let dev = me.devices.remove(at: idx)
                dev.close()
                me.onDisconnect?(dev)
            }
        }, context)
    }

    /// Begin watching. Already-attached devices are reported immediately.
    public func start() {
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    public func stop() {
        for d in devices { d.close() }
        devices.removeAll()
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
}
