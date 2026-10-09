import Foundation
import CoreMIDI

/// A virtual Mackie Control surface that Logic Pro discovers by itself.
///
/// Logic polls MIDI ports with a device query sysex; we answer as a Mackie
/// Control unit, Logic installs the surface, and from then on transport
/// buttons are note-ons and the jog wheel is a relative CC.
final class MackieControl {
    var onPlayState: ((Bool) -> Void)?
    var onRecordState: ((Bool) -> Void)?
    var onLog: ((String) -> Void)?
    private(set) var isPlaying = false
    private(set) var isRecording = false

    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private var destination = MIDIEndpointRef()
    private var sysexBuffer: [UInt8] = []
    private let serial: [UInt8] = Array("SEB0001".utf8)
    private static let header: [UInt8] = [0xf0, 0x00, 0x00, 0x66, 0x14]

    init(name: String = "Speed Editor Bridge") {
        MIDIClientCreateWithBlock(name as CFString, &client) { _ in }
        MIDISourceCreate(client, name as CFString, &source)
        MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, 0x5ed1_0001)
        MIDIDestinationCreateWithBlock(client, name as CFString, &destination) { [weak self] packetList, _ in
            self?.receive(packetList)
        }
        MIDIObjectSetIntegerProperty(destination, kMIDIPropertyUniqueID, 0x5ed1_0002)
    }

    deinit {
        MIDIEndpointDispose(destination)
        MIDIEndpointDispose(source)
        MIDIClientDispose(client)
    }

    // MARK: Sending

    func send(_ bytes: [UInt8]) {
        var list = MIDIPacketList()
        let packet = MIDIPacketListInit(&list)
        bytes.withUnsafeBufferPointer { buf in
            _ = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size + bytes.count + 64, packet, 0, bytes.count, buf.baseAddress!)
        }
        MIDIReceived(source, &list)
    }

    func buttonDown(_ b: MackieButton) { send([0x90, b.rawValue, 0x7f]) }
    func buttonUp(_ b: MackieButton) { send([0x90, b.rawValue, 0x00]) }

    func press(_ b: MackieButton) {
        buttonDown(b)
        buttonUp(b)
    }

    func chord(holding h: MackieButton, press b: MackieButton) {
        buttonDown(h)
        press(b)
        buttonUp(h)
    }

    /// Jog wheel: one relative tick per message.
    func jog(_ steps: Int) {
        guard steps != 0 else { return }
        let value: UInt8 = steps > 0 ? 0x01 : 0x41
        for _ in 0..<min(abs(steps), 32) { send([0xb0, 0x3c, value]) }
    }

    func playStop() {
        press(isPlaying ? .stop : .play)
    }

    // MARK: Receiving

    private func receive(_ packetList: UnsafePointer<MIDIPacketList>) {
        var bytes: [UInt8] = []
        for packet in packetList.unsafeSequence() {
            let length = Int(packet.pointee.length)
            withUnsafeBytes(of: packet.pointee.data) { raw in
                bytes.append(contentsOf: raw.prefix(length))
            }
        }
        DispatchQueue.main.async { [weak self] in self?.handle(bytes) }
    }

    private func handle(_ bytes: [UInt8]) {
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == 0xf0 || !sysexBuffer.isEmpty {
                sysexBuffer.append(b)
                if b == 0xf7 {
                    handleSysex(sysexBuffer)
                    sysexBuffer.removeAll()
                }
                i += 1
                continue
            }
            if b & 0xf0 == 0x90, i + 2 < bytes.count {
                let note = bytes[i + 1], vel = bytes[i + 2]
                if note == MackieButton.play.rawValue {
                    isPlaying = vel != 0
                    onPlayState?(isPlaying)
                } else if note == MackieButton.record.rawValue {
                    isRecording = vel != 0
                    onRecordState?(isRecording)
                }
                i += 3
            } else if b & 0xf0 == 0xb0 || b & 0xf0 == 0xa0 || b & 0xf0 == 0xe0 {
                i += 3
            } else if b & 0xf0 == 0xc0 || b & 0xf0 == 0xd0 {
                i += 2
            } else {
                i += 1
            }
        }
    }

    private func handleSysex(_ msg: [UInt8]) {
        guard msg.count >= 7, Array(msg.prefix(5)) == Self.header else { return }
        switch msg[5] {
        case 0x00:
            // Device query: answer with a host connection query carrying our serial.
            onLog?("Logic queried the surface; answering as Mackie Control")
            send(Self.header + [0x01] + serial + [0x01, 0x02, 0x03, 0x04] + [0xf7])
        case 0x02:
            // Host connection reply: accept and confirm.
            send(Self.header + [0x03] + serial + [0xf7])
            onLog?("Logic connected the control surface")
        case 0x13:
            send(Self.header + [0x14] + Array("V1.00".utf8) + [0xf7])
        default:
            break
        }
    }
}
