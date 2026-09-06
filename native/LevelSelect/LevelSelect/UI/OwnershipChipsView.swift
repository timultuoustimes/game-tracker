import SwiftUI
import SwiftData

/// Which ownership chips this library uses.
///
/// Ownership is the one vocabulary in the app that is genuinely
/// person-specific. A PC-only library has no use for Physical; somebody
/// cataloguing a childhood has every use for Rented and none for Subscription.
/// Tim, arriving at it from a memory of a Halo 2 he never owned: *"maybe we
/// let them choose what ownership options they want displayed?"*
///
/// **Hiding one never changes a game.** A game already marked with a hidden
/// chip keeps the mark and keeps showing it — see `OwnershipControl`. Turning
/// a chip off is a decision about what you want to think about, not an edit to
/// your library, and the footer says so because a screen full of switches
/// beside the word "ownership" invites the other reading.
struct OwnershipChipsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ThemeSettings.createdAt) private var themeSettings: [ThemeSettings]

    private var settings: ThemeSettings? { themeSettings.first }
    private var chosen: [Ownership] {
        ThemePalette.chips(from: settings?.ownershipChipsRaw)
    }

    var body: some View {
        SettingsPage(title: "Ownership chips",
                     icon: "shippingbox",
                     blurb: "The ways you can say a game is yours. Turn off the ones your library never uses.") {
            Section {
                ForEach(Ownership.allCases, id: \.self) { kind in
                    Toggle(isOn: binding(for: kind)) {
                        Label(kind.label, systemImage: kind.systemImage)
                    }
                    .tint(LSTheme.accent)
                }
            } footer: {
                Text("Turning one off only hides it. A game already marked with it keeps the mark, and keeps showing it, so nothing you recorded is lost. Syncs to your other devices.")
            }

            if chosen.count == 1 {
                Section {
                    Label("One chip left. Turning off the last one puts all six back — a game page with no way to say you own the game isn't a state worth having.",
                          systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func binding(for kind: Ownership) -> Binding<Bool> {
        Binding(
            get: { chosen.contains(kind) },
            set: { on in
                var next = Set(chosen)
                if on { next.insert(kind) } else { next.remove(kind) }
                let settings = ThemePalette.fetchOrCreate(in: context)
                // Written in `allCases` order so two devices that choose the
                // same set store the same string — the same rule the expanded
                // sections use.
                settings.ownershipChipsRaw = Ownership.allCases
                    .filter(next.contains)
                    .map(\.rawValue)
                    .joined(separator: ",")
                settings.updatedAt = .now
            })
    }
}
