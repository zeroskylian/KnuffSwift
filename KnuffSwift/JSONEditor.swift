import AppKit
import SwiftUI

struct JSONEditor: View {
    @Binding var text: String

    private var lineNumbers: String {
        let count = max(1, text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
        return (1...count).map(String.init).joined(separator: "\n")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(lineNumbers)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineSpacing(2)
                .frame(width: 32, alignment: .trailing)
                .padding(.top, 9)
                .padding(.trailing, 7)
                .accessibilityHidden(true)

            Divider()

            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(1)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .disableAutocorrection(true)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
