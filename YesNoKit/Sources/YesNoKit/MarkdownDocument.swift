import Foundation

/// A tiny block-level Markdown reader for the bundled privacy policy.
///
/// The policy lives once in `docs/privacy.md`; the website renders it and the app
/// ships the same file so it can be read offline. Only what that file uses is
/// supported: `#`/`##`/`###` headings, `-` bullets, and paragraphs. Inline
/// formatting (bold, links) is left in the text for the UI to render.
public struct MarkdownDocument: Equatable, Sendable {
    public enum Block: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)
    }

    public let blocks: [Block]

    public init(_ source: String) {
        var blocks: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if let heading = Self.heading(in: line) {
                flushParagraph()
                blocks.append(heading)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else if case .bullet(let previous)? = blocks.last, paragraph.isEmpty, rawLine.hasPrefix("  ") {
                // Indented continuation of the previous bullet.
                blocks[blocks.count - 1] = .bullet(previous + " " + line)
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        self.blocks = blocks
    }

    private static func heading(in line: String) -> Block? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...3).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        return .heading(level: hashes, text: rest.trimmingCharacters(in: .whitespaces))
    }
}
