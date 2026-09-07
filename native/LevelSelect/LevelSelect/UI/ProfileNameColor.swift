import SwiftUI

/// How the profile name on Home is colored.
///
/// Three states in one string, because the interesting one isn't a color at
/// all: **following the accent** means the name keeps changing with the theme
/// rather than being pinned to whatever the accent happened to be the day it
/// was set.
///
/// **Device-local for now.** Storing this per-profile means a new field on
/// `PlayerProfile`, which is a CloudKit schema deploy. Queued with the two
/// others waiting on the same dance — a live-linked "use my handle as my name"
/// toggle, and syncing kept swatches — so one deploy covers all three rather
/// than three deploys covering one each.
enum ProfileNameColor {
    static let key = "levelselect.profileNameColor"

    /// Follow the accent, whatever it becomes later.
    static let accent = "accent"
    /// The plain default: ordinary primary text.
    static let plain = ""

    @MainActor
    static func resolve(_ raw: String) -> Color {
        switch raw {
        case plain:  .primary
        case accent: LSTheme.displayAccent
        default:     Color(hex: raw) ?? .primary
        }
    }

    /// The hard step that goes under the name, following the wordmark's rule.
    ///
    /// `Wordmark.shadowTint`: the brand orange gets the brand's own dark
    /// orange beneath it, and a color the user picked gets a darkened version
    /// of itself. This is the only other pixel-type string in the app, and Tim
    /// named that pairing as the thing that made torch work on a light ground
    /// — *"especially with the secondary dark orange as it's hard edge drop
    /// shadow."*
    @MainActor
    static func step(under ink: Color, raw: String) -> Color {
        if raw == accent, !ThemePalette.accentIsCustom { return LSTheme.torchShadow }
        return LSTheme.hardStep(under: ink)
    }

    /// The swatch to show for a setting, so the row previews the real thing.
    @MainActor
    static func swatch(_ raw: String) -> Color { resolve(raw) }

    enum Mode: String, CaseIterable, Identifiable {
        case plain, accent, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .plain:  "Default"
            case .accent: "Accent"
            case .custom: "Custom"
            }
        }
    }

    static func mode(of raw: String) -> Mode {
        switch raw {
        case plain:  .plain
        case accent: .accent
        default:     .custom
        }
    }
}
