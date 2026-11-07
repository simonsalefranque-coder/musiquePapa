import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var folder = false
    var onPick: ([URL]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // .item deliberately allows provider-specific ChordPro UTIs; validate extensions/content after selection.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: folder ? [.folder] : [.item], asCopy: false)
        picker.allowsMultipleSelection = !folder
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TestsImport")
        }
        #endif
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onPick(urls) }
    }
}
