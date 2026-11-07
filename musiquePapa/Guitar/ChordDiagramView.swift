import SwiftUI

struct ChordDiagramView: View {
    let symbol: String
    let capo: String
    let close: () -> Void
    @State private var index = 0
    private var positions: [GuitarFingering] { ChordFingeringLibrary.positions(for: symbol) }
    var body: some View {
        ScrollView { VStack(spacing: 12) {
            HStack {
                Text(symbol).font(.largeTitle.bold()).accessibilityIdentifier("diagramChord")
                Spacer()
                Button("Fermer", action: close).buttonStyle(.bordered).accessibilityIdentifier("closeDiagram")
            }
            if positions.isEmpty {
                Text("Aucun doigté vérifié disponible pour cet accord. Le symbole de la partition est conservé.").padding(.vertical, 25)
            } else {
                let position = positions[min(index, positions.count - 1)]
                Picker("Position", selection: $index) {
                    ForEach(positions.indices, id: \.self) { i in Text("\(i + 1) · \(positions[i].name)").tag(i) }
                }.pickerStyle(.menu).accessibilityIdentifier("diagramPosition")
                GuitarDiagram(fingering: position).frame(width: 280, height: 285)
                Text("Mi grave à gauche · Mi aigu à droite\nX : ne pas jouer · O : corde à vide\n1 index · 2 majeur · 3 annulaire · 4 auriculaire").font(.caption).multilineTextAlignment(.center)
            }
            if !capo.isEmpty {
                if let fret = Int(capo), (0...12).contains(fret) {
                    Text("Capo \(fret) · Forme jouée : \(symbol)\nAccord entendu : \(Transposer.transpose(symbol, by: fret))")
                        .font(.subheadline).multilineTextAlignment(.center)
                } else { Text("Capo indiqué : \(capo). Le diagramme montre la forme écrite.").font(.subheadline) }
                Text("Les cases du diagramme sont comptées depuis le capo.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Lecture en pause. Fermez puis appuyez sur Lecture pour reprendre.").font(.caption).foregroundStyle(.secondary)
        }.padding(22) }.frame(width: 350)
    }
}
struct GuitarDiagram: View {
    let fingering: GuitarFingering
    var body: some View {
        Canvas { context, _ in
            let left: CGFloat = 44, top: CGFloat = 42, dx: CGFloat = 38, dy: CGFloat = 47
            for string in 0..<6 {
                var path = Path(); path.move(to: CGPoint(x: left + CGFloat(string) * dx, y: top)); path.addLine(to: CGPoint(x: left + CGFloat(string) * dx, y: top + 4 * dy))
                context.stroke(path, with: .color(.primary), lineWidth: 1)
            }
            for fret in 0...4 {
                var path = Path(); path.move(to: CGPoint(x: left, y: top + CGFloat(fret) * dy)); path.addLine(to: CGPoint(x: left + 5 * dx, y: top + CGFloat(fret) * dy))
                context.stroke(path, with: .color(.primary), lineWidth: fret == 0 && fingering.firstFret == 1 ? 4 : 1)
            }
            context.draw(Text("\(fingering.firstFret)").font(.headline), at: CGPoint(x: 20, y: top + dy / 2))
            for barre in fingering.barres {
                let y = top + (CGFloat(barre.fret - fingering.firstFret) + 0.5) * dy
                let rect = CGRect(x: left + CGFloat(barre.from) * dx - 11, y: y - 11, width: CGFloat(barre.to - barre.from) * dx + 22, height: 22)
                context.fill(Path(roundedRect: rect, cornerRadius: 11), with: .color(.blue))
            }
            for string in 0..<6 {
                let fret = fingering.frets[string], x = left + CGFloat(string) * dx
                if fret <= 0 { context.draw(Text(fret < 0 ? "X" : "O").font(.headline), at: CGPoint(x: x, y: 20)) }
                else {
                    let y = top + (CGFloat(fret - fingering.firstFret) + 0.5) * dy
                    context.fill(Path(ellipseIn: CGRect(x: x - 12, y: y - 12, width: 24, height: 24)), with: .color(.blue))
                    let finger = fingering.fingers[string]
                    if finger > 0 { context.draw(Text("\(finger)").font(.system(size: 14, weight: .bold)).foregroundColor(.white), at: CGPoint(x: x, y: y)) }
                }
            }
            for (i, name) in ["Mi", "La", "Ré", "Sol", "Si", "Mi"].enumerated() { context.draw(Text(name).font(.caption), at: CGPoint(x: left + CGFloat(i) * dx, y: 250)) }
        }.accessibilityElement().accessibilityLabel("\(fingering.name). Cordes du grave à l’aigu : " + fingering.frets.map { $0 < 0 ? "muette" : $0 == 0 ? "à vide" : "case \($0)" }.joined(separator: ", "))
    }
}
