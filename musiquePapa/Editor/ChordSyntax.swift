import UIKit

enum ChordSyntax {
    struct Token { var range: NSRange; var color: UIColor; var warning = false; var isChord = false }
    static func tokens(_ source: String) -> [Token] {
        let text = source as NSString
        var tokens: [Token] = []
        var tab = false
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            let line = text.substring(with: range), trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { tokens.append(Token(range: range, color: .systemGreen)); return }
            if trimmed.hasPrefix("{") {
                let directive = trimmed.dropFirst().split(separator: ":", maxSplits: 1).first.map(String.init)?.replacingOccurrences(of: "}", with: "").trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                let comment = ["comment", "c", "ci", "cb", "comment_italic", "comment_box"].contains(directive)
                tokens.append(Token(range: range, color: comment ? .systemGreen : .systemPurple, warning: !trimmed.hasSuffix("}")))
                if ["start_of_tab", "sot"].contains(directive) { tab = true }
                if ["end_of_tab", "eot"].contains(directive) { tab = false }
                return
            }
            guard !tab else { return }
            let regex = try! NSRegularExpression(pattern: #"\[[^\[\]\r\n]*\]|\[[^\]\r\n]*|\]"#)
            for match in regex.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                let part = (line as NSString).substring(with: match.range)
                let valid = part.hasPrefix("[") && part.hasSuffix("]") && ChordSourceEditing.validChord(String(part.dropFirst().dropLast()))
                tokens.append(Token(range: NSRange(location: range.location + match.range.location, length: match.range.length), color: .systemBlue, warning: !valid, isChord: true))
            }
        }
        return tokens
    }
    static func highlight(_ view: UITextView, fontSize: CGFloat) {
        guard view.markedTextRange == nil else { return }
        let selection = view.selectedRange, offset = view.contentOffset
        let storage = view.textStorage
        let manager = view.undoManager, wasEnabled = manager?.isUndoRegistrationEnabled == true
        if wasEnabled { manager?.disableUndoRegistration() }
        storage.beginEditing()
        storage.setAttributes([.font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), .foregroundColor: UIColor.label], range: NSRange(location: 0, length: storage.length))
        for token in tokens(view.text) {
            storage.addAttribute(.foregroundColor, value: token.color, range: token.range)
            if token.warning {
                storage.addAttributes([.underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: UIColor.systemOrange], range: token.range)
            }
        }
        storage.endEditing()
        if wasEnabled { manager?.enableUndoRegistration() }
        view.selectedRange = selection; view.contentOffset = offset
        view.typingAttributes = [.font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), .foregroundColor: UIColor.label]
    }
}
