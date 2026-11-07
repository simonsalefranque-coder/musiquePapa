import SwiftUI

struct ChordColorControls: View {
    let value: ChordColor
    let onChange: (ChordColor) -> Void
    var body: some View {
        ForEach(ChordColor.presets, id: \.0) { name, color in
            Button { onChange(color) } label: {
                HStack {
                    Circle().fill(color.color).overlay(Circle().stroke(.gray, lineWidth: 0.5)).frame(width: 22, height: 22)
                    Text(name).foregroundStyle(.primary)
                    Spacer()
                    if value == color { Image(systemName: "checkmark").foregroundStyle(.tint) }
                }.padding(.vertical, 3)
            }.accessibilityIdentifier("chordColor-\(name)")
        }
        ColorPicker("Couleur personnalisée", selection: Binding(get: { value.color }, set: { onChange(ChordColor($0)) }), supportsOpacity: false)
        Text("La luminosité s’adapte au thème pour que les accords restent lisibles, y compris avec le noir et le blanc.").font(.footnote).foregroundStyle(.secondary)
    }
}
