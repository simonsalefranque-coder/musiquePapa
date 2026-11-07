import SwiftUI

/// A single List owns scrolling inside a modal sheet. It does not inherit any
/// pan or pinch recognizer from the UIKit score, unlike a long contextual Menu.
struct TonalityView: View {
    @ObservedObject var session: ReaderSession
    @Environment(\.dismiss) private var dismiss
    @State private var editingOriginal = false
    @State private var mode: MusicalKey.Mode = .major
    private var selected: MusicalKey? { editingOriginal ? session.originalKey : session.preferences.displayKey ?? session.originalKey }
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Origine : \(session.originalKey?.label ?? "À renseigner")").accessibilityIdentifier("originalKeyLabel")
                    Text("Affichage : \(session.preferences.displayKey?.label ?? (session.transpose == 0 ? session.originalKey?.label ?? "Accords du fichier" : "\(session.transpose) demi-tons"))").accessibilityIdentifier("displayKeyLabel")
                    Picker("Tonalité à définir", selection: $editingOriginal) { Text("Affichage").tag(false); Text("Origine").tag(true) }.pickerStyle(.segmented)
                    Picker("Mode", selection: $mode) { ForEach(MusicalKey.Mode.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    if let original = session.originalKey, let target = session.preferences.displayKey, original.mode != target.mode {
                        Label("Les accords gardent leur nature majeure ou mineure. Ce choix de mode ne réharmonise pas le morceau.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal).padding(.top)
                List {
                    if !editingOriginal && session.originalKey == nil {
                        Text("Renseignez d’abord la tonalité d’origine. Elle sert de référence pour transposer les accords.").foregroundStyle(.secondary)
                        Button("Définir la tonalité d’origine") { editingOriginal = true }
                    }
                    ForEach(Array(MusicalKey.chromatic.enumerated()), id: \.offset) { index, names in
                        HStack {
                            ForEach(names, id: \.self) { tonic in
                                let key = MusicalKey(tonic: tonic, mode: mode)
                                Button {
                                    session.setKey(key, original: editingOriginal)
                                } label: {
                                    HStack {
                                        Text("\(MusicalKey.french(tonic)) (\(key.symbol))").frame(maxWidth: .infinity, alignment: .leading)
                                        if selected == key { Image(systemName: "checkmark.circle.fill") }
                                    }.padding(.vertical, 9).contentShape(Rectangle())
                                }.buttonStyle(.borderless).accessibilityIdentifier("key-\(tonic)-\(mode.rawValue)")
                                    .disabled(!editingOriginal && session.originalKey == nil)
                                if tonic == names.first && names.count == 2 { Divider() }
                            }
                        }.id(index)
                    }
                    Section("Transposition en demi-tons") {
                        Stepper("\(session.transpose > 0 ? "+" : "")\(session.transpose) demi-tons", value: Binding(get: { session.transpose }, set: session.setTranspose), in: -12...12)
                        Button("Revenir à la tonalité d’origine", action: session.resetKey)
                    }
                    Section {
                        Text("La transposition déplace les accords sans changer leur nature majeure ou mineure. Changer le mode ne réharmonise pas les paroles et les accords. Le capo reste indépendant. Le fichier original est conservé.").font(.footnote).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("keyList")
            }
            .navigationTitle("Tonalité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
            .onAppear { editingOriginal = session.originalKey == nil; mode = selected?.mode ?? .major }
            .onChange(of: editingOriginal) { _, _ in mode = selected?.mode ?? .major }
        }
    }
}
