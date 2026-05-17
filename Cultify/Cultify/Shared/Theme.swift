import SwiftUI

/// Neutral, warm-cream palette — Apple HIG "light" feel.
enum Theme {
    // Surfaces
    static let bg            = Color(hex: 0xF5F2EC)   // page background (warm cream)
    static let surface       = Color.white            // primary card surface
    static let surfaceMuted  = Color(hex: 0xEFEAE0)   // chip / subtle highlight
    static let stroke        = Color.black.opacity(0.06)
    static let avatarBg      = Color(hex: 0xE8E2D9)   // round avatar fill

    // Text
    static let textPrimary   = Color(hex: 0x1A1A1A)
    static let textSecondary = Color(hex: 0x8A8784)
    static let textMuted     = Color(hex: 0xB8B5B0)

    // Action
    static let accent        = Color(hex: 0x1A1A1A)   // primary CTAs (near-black)
    static let accentSoft    = Color(hex: 0xC26344)   // muted terracotta highlight

    // Chip variants (subtle, like the "more details" pill in the reference)
    static let chipBlueBg    = Color(hex: 0xE6ECFB)
    static let chipBlueFg    = Color(hex: 0x3B6FE5)

    // Semantic
    static let success       = Color(hex: 0x4D8B5C)
    static let warning       = Color(hex: 0xC28B47)
    static let danger        = Color(hex: 0xB8473F)

    enum Radius {
        static let card: CGFloat   = 20
        static let item: CGFloat   = 16
        static let input: CGFloat  = 14
        static let pill: CGFloat   = 100   // capsule-ish for chips
    }
}

enum BodyPart: String, CaseIterable {
    case chest, back, shoulders, arms, legs, core, cardio, other

    init(name: String?) {
        self = BodyPart(rawValue: name?.lowercased() ?? "") ?? .other
    }

    /// Muted, desaturated chip colors that fit the neutral palette.
    var fg: Color {
        switch self {
        case .chest:     return Color(hex: 0xB55A3E)
        case .back:      return Color(hex: 0x4A6FA5)
        case .shoulders: return Color(hex: 0xB58840)
        case .arms:      return Color(hex: 0x8056A4)
        case .legs:      return Color(hex: 0x5B8A66)
        case .core:      return Color(hex: 0xA85178)
        case .cardio:    return Color(hex: 0xB8473F)
        case .other:     return Color(hex: 0x8A8784)
        }
    }

    var bg: Color { fg.opacity(0.12) }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Typography helpers

enum Font2 {
    static let pageTitle = Font.system(size: 38, weight: .heavy, design: .default)
    static let sectionLabel = Font.system(size: 11, weight: .semibold).width(.condensed)
    static let rowTitle = Font.system(size: 17, weight: .semibold)
    static let rowSubtitle = Font.system(size: 14, weight: .regular)
    static let value = Font.system(size: 17, weight: .semibold)
    static let dateMicro = Font.system(size: 12, weight: .regular)
}

// MARK: - Modifiers

struct CardSurface: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

struct ListItemSurface: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.item, style: .continuous))
    }
}

extension View {
    func cardSurface(padding: CGFloat = 18) -> some View { modifier(CardSurface(padding: padding)) }
    func listItem(padding: CGFloat = 14) -> some View { modifier(ListItemSurface(padding: padding)) }
}

// MARK: - Avatars

struct InitialsAvatar: View {
    let text: String
    var size: CGFloat = 50

    var body: some View {
        ZStack {
            Circle().fill(Theme.avatarBg)
            Text(initials)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let parts = text.split(separator: " ").compactMap { $0.first }.map(String.init)
        if parts.count >= 2 { return (parts[0] + parts[1]).uppercased() }
        return text.prefix(2).uppercased()
    }
}

/// The reference design wraps the avatar in a white rounded-rectangle pill —
/// a small "halo" around the beige circle.
struct AvatarPill: View {
    let text: String
    var body: some View {
        InitialsAvatar(text: text, size: 42)
            .padding(5)
            .background(Theme.surface)
            .clipShape(Capsule())
    }
}

/// Round avatar with beige background + a dark icon, used for exercise/meal rows.
struct IconAvatar: View {
    let systemName: String
    var tint: Color = Theme.textPrimary
    var size: CGFloat = 50

    var body: some View {
        ZStack {
            Circle().fill(Theme.avatarBg)
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Font2.sectionLabel)
            .tracking(0.7)
            .foregroundStyle(Theme.textMuted)
    }
}
