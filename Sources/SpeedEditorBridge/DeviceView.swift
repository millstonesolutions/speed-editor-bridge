import SwiftUI
import SpeedEditorKit

enum Brand {
    static let cyan = Color(red: 0x02 / 255, green: 0xCA / 255, blue: 0xF2 / 255)
    static let blue = Color(red: 0x09 / 255, green: 0x7D / 255, blue: 0xDB / 255)
    static let gray1 = Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF7 / 255)
    static let gray2 = Color(red: 0xD0 / 255, green: 0xD4 / 255, blue: 0xD7 / 255)
    static let gray3 = Color(red: 0x97 / 255, green: 0x97 / 255, blue: 0x97 / 255)
    static let gray4 = Color(red: 0x59 / 255, green: 0x59 / 255, blue: 0x59 / 255)
    static let panel = Color(white: 0.11)
    static let tile = Color(white: 0.18)
}

/// Schematic of the Speed Editor with the active mapping on every key.
struct DeviceView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProfileStore
    @Binding var editingKey: SpeedEditorKey?

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.width / PanelLayout.columns
            let rowH = min(unit * 0.85, geo.size.height / PanelLayout.rows)
            let gap = unit * 0.07
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18).fill(Brand.panel)
                wheel(unit: unit, rowH: rowH)
                ForEach(PanelLayout.tiles) { tile in
                    KeyTileView(tile: tile, editing: editingKey == tile.key)
                        .frame(width: tile.w * unit - gap, height: rowH - gap)
                        .offset(x: tile.x * unit + gap / 2, y: tile.y * rowH + gap / 2)
                        .onTapGesture { editingKey = tile.key }
                }
            }
        }
    }

    private func wheel(unit: CGFloat, rowH: CGFloat) -> some View {
        let r = PanelLayout.wheelRadius * unit
        let cx = PanelLayout.wheelCenter.x * unit
        let cy = PanelLayout.wheelCenter.y * rowH
        return ZStack {
            Circle().fill(Color(white: 0.15)).overlay(Circle().stroke(Brand.gray4, lineWidth: 2))
            Circle().fill(Color(white: 0.2)).padding(r * 0.35)
            VStack(spacing: 2) {
                Text(engine.wheelMode.label).font(.system(size: unit * 0.22, weight: .heavy)).foregroundStyle(Brand.cyan)
                Text(wheelSummary).font(.system(size: unit * 0.11)).foregroundStyle(Brand.gray2).multilineTextAlignment(.center)
                if engine.wheelMode == .shuttle {
                    Text(shuttleLabel).font(.system(size: unit * 0.13, weight: .bold)).foregroundStyle(Brand.gray1)
                }
            }
            .padding(r * 0.3)
        }
        .frame(width: r * 2, height: r * 2)
        .offset(x: cx - r, y: cy - r)
    }

    private var wheelSummary: String {
        let p = engine.activeProfile
        if let hold = engine.pressedKeys.first(where: { p.holdWheel[$0.name] != nil }), let wk = p.holdWheel[hold.name] {
            return "\(hold.legend): \(wk.summary)"
        }
        switch engine.wheelMode {
        case .jog: return p.jog.summary
        case .scroll: return p.scroll.summary
        case .shuttle: return p.shuttle.label
        }
    }

    private var shuttleLabel: String {
        let names = ["stop", "½×", "1×", "2×", "4×", "8×", "16×"]
        let l = engine.shuttleLevel
        if l == 0 { return "■ stop" }
        return (l < 0 ? "◀ " : "") + names[abs(l)] + (l > 0 ? " ▶" : "")
    }
}

struct KeyTileView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProfileStore
    let tile: KeyTile
    let editing: Bool

    var body: some View {
        let profile = engine.activeProfile
        let action = profile.action(for: tile.key)
        let pressed = engine.pressedKeys.contains(tile.key)
        let overridden = !store.isDefault(tile.key, in: profile.id)
        let isModeKey: Bool = { if case .wheelMode(let m) = action { return m == engine.wheelMode } else { return false } }()
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(pressed ? Brand.cyan : (isModeKey ? Brand.blue.opacity(0.55) : Brand.tile))
            RoundedRectangle(cornerRadius: 7)
                .stroke(editing ? Brand.cyan : Color.clear, lineWidth: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(tile.key.legend)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(pressed ? .black : Brand.gray1)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text(action.summary)
                    .font(.system(size: 12, weight: action.isAssigned ? .semibold : .regular))
                    .foregroundStyle(pressed ? .black : (action.isAssigned ? Brand.cyan : Brand.gray3))
                    .lineLimit(2).minimumScaleFactor(0.55)
            }
            .padding(6)
            if overridden {
                Circle().fill(Brand.gray1).frame(width: 6, height: 6).padding(5)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
        }
        .contentShape(Rectangle())
        .help(helpText(action: action, overridden: overridden))
    }

    private func helpText(action: Action, overridden: Bool) -> String {
        var s = "\(tile.key.legend): \(action.summary)"
        if overridden { s += " (customised)" }
        if engine.activeProfile.holdWheel[tile.key.name] != nil { s += "\nHold and turn the wheel to nudge" }
        return s
    }
}
