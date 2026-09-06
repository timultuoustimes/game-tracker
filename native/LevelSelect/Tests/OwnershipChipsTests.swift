import Testing
import Foundation
@testable import LevelSelect

/// Which ownership chips a library uses, and the promise that hiding one is
/// not an edit.
@MainActor
struct OwnershipChipsTests {

    @Test func nothingStoredMeansTheDefaultFive() {
        #expect(ThemePalette.chips(from: nil) == Ownership.shownByDefault)
        #expect(!Ownership.shownByDefault.contains(.rented))
    }

    /// Rented is real, and off until asked for: most libraries will never
    /// record a weekend rental, and the ones that do are cataloguing a
    /// childhood rather than a subscription.
    @Test func rentedIsAvailableButNotADefault() {
        #expect(Ownership.allCases.contains(.rented))
        #expect(Ownership.rented.label == "Rented")
    }

    @Test func aStoredSetIsHonoured() {
        let chips = ThemePalette.chips(from: "physical,rented")
        #expect(chips == [.physical, .rented])
    }

    /// Stored order is ignored — the app's own order is what keeps the chips
    /// in the same places on every game page whatever order they were toggled.
    @Test func theAppsOwnOrderWins() {
        #expect(ThemePalette.chips(from: "rented,physical") == [.physical, .rented])
    }

    /// A game page with no way to say you own the game is not a state worth
    /// having, so an empty set falls back rather than rendering nothing.
    @Test func anEmptySetFallsBackToTheDefaults() {
        #expect(ThemePalette.chips(from: "") == Ownership.shownByDefault)
    }

    /// A raw value this build has never heard of — written by a later one and
    /// arriving over CloudKit — is ignored rather than breaking the row.
    @Test func anUnknownChipIsIgnored() {
        #expect(ThemePalette.chips(from: "physical,borrowed") == [.physical])
    }

    /// The whole set decoding to nothing known is the same as nothing stored.
    @Test func aWhollyUnknownSetFallsBack() {
        #expect(ThemePalette.chips(from: "borrowed,leased") == Ownership.shownByDefault)
    }

    @Test func everyChipIsStillASingleWord() {
        for kind in Ownership.allCases {
            #expect(!kind.label.contains(" "),
                    Comment(rawValue: "\(kind.rawValue) → \"\(kind.label)\""))
        }
    }
}
