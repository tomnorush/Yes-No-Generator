import SwiftUI
import YesNoKit

/// Colors for one answer: the full-screen background and the text drawn on it.
struct AnswerPalette: Equatable {
    let background: Color
    let foreground: Color
}

/// A color scheme for the answer screen. Classic is free and follows light/dark mode;
/// the others come with Pro.
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let isPro: Bool
    fileprivate let light: [Answer: AnswerPalette]
    fileprivate let dark: [Answer: AnswerPalette]

    func palette(for answer: Answer, in scheme: ColorScheme) -> AnswerPalette {
        let table = scheme == .dark ? dark : light
        return table[answer] ?? AnswerPalette(background: .black, foreground: .white)
    }

    static let classic = Theme(
        id: "classic", name: "Classic", isPro: false,
        light: [
            .yes: AnswerPalette(background: Color(hex: 0xE3F5E8), foreground: Color(hex: 0x0E5A2B)),
            .no: AnswerPalette(background: Color(hex: 0xFCE6E4), foreground: Color(hex: 0x8C1D14)),
            .maybe: AnswerPalette(background: Color(hex: 0xFFF3D6), foreground: Color(hex: 0x6B4A00)),
        ],
        dark: [
            .yes: AnswerPalette(background: Color(hex: 0x0C2616), foreground: Color(hex: 0x7BE3A0)),
            .no: AnswerPalette(background: Color(hex: 0x2E0F0C), foreground: Color(hex: 0xFF9A8F)),
            .maybe: AnswerPalette(background: Color(hex: 0x2B2106), foreground: Color(hex: 0xFFD166)),
        ]
    )

    static let bold = Theme.fixed(
        id: "bold", name: "Bold",
        yes: (0x16723A, 0xFFFFFF), no: (0xB3261E, 0xFFFFFF), maybe: (0x8A5A00, 0xFFFFFF)
    )

    static let ocean = Theme.fixed(
        id: "ocean", name: "Ocean",
        yes: (0x00695C, 0xFFFFFF), no: (0x1A237E, 0xFFFFFF), maybe: (0x37474F, 0xFFFFFF)
    )

    static let sunset = Theme.fixed(
        id: "sunset", name: "Sunset",
        yes: (0xB33F00, 0xFFFFFF), no: (0x5B1A7A, 0xFFFFFF), maybe: (0x9C1D55, 0xFFFFFF)
    )

    static let forest = Theme.fixed(
        id: "forest", name: "Forest",
        yes: (0x2F5D2F, 0xF1F8E9), no: (0x4E342E, 0xFBE9E7), maybe: (0x5D5A1A, 0xFFFDE7)
    )

    static let candy = Theme.fixed(
        id: "candy", name: "Candy",
        yes: (0xB8F2CC, 0x0B3D1E), no: (0xFFD1DC, 0x6A0F2A), maybe: (0xFFF1A8, 0x4A3B00)
    )

    static let mono = Theme(
        id: "mono", name: "Mono", isPro: true,
        light: [
            .yes: AnswerPalette(background: Color(hex: 0x111111), foreground: Color(hex: 0xFFFFFF)),
            .no: AnswerPalette(background: Color(hex: 0xF4F4F4), foreground: Color(hex: 0x111111)),
            .maybe: AnswerPalette(background: Color(hex: 0x5E5E5E), foreground: Color(hex: 0xFFFFFF)),
        ],
        dark: [
            .yes: AnswerPalette(background: Color(hex: 0xF4F4F4), foreground: Color(hex: 0x111111)),
            .no: AnswerPalette(background: Color(hex: 0x111111), foreground: Color(hex: 0xFFFFFF)),
            .maybe: AnswerPalette(background: Color(hex: 0x5E5E5E), foreground: Color(hex: 0xFFFFFF)),
        ]
    )

    static let all: [Theme] = [.classic, .bold, .ocean, .sunset, .forest, .candy, .mono]

    static func with(id: String) -> Theme {
        all.first { $0.id == id } ?? .classic
    }

    /// A Pro theme that looks the same in light and dark mode.
    private static func fixed(
        id: String, name: String,
        yes: (UInt32, UInt32), no: (UInt32, UInt32), maybe: (UInt32, UInt32)
    ) -> Theme {
        let table: [Answer: AnswerPalette] = [
            .yes: AnswerPalette(background: Color(hex: yes.0), foreground: Color(hex: yes.1)),
            .no: AnswerPalette(background: Color(hex: no.0), foreground: Color(hex: no.1)),
            .maybe: AnswerPalette(background: Color(hex: maybe.0), foreground: Color(hex: maybe.1)),
        ]
        return Theme(id: id, name: name, isPro: true, light: table, dark: table)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Appearance {
    /// `nil` means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
