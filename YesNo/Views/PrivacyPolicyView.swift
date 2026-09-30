import SwiftUI
import YesNoKit

/// Shows the same privacy policy that is published on the website, bundled so it reads offline.
struct PrivacyPolicyView: View {
    private let document: MarkdownDocument = {
        guard let url = Bundle.main.url(forResource: "privacy", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return MarkdownDocument("# Privacy Policy\n\nYes or No collects no data. Nothing you do in the app leaves your device.")
        }
        return MarkdownDocument(text)
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func view(for block: MarkdownDocument.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(level == 1 ? Font.title.bold() : level == 2 ? Font.title3.bold() : Font.headline)
                .padding(.top, level == 1 ? 0 : 8)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(inline(text))
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").accessibilityHidden(true)
                Text(inline(text))
            }
        }
    }

    /// Bold, italics and links inside a line.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
