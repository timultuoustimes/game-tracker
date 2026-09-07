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

/// **Chip order, and the field it hides in.**
///
/// Three orders — the app's own, most used in your library, and whatever you
/// dragged — stored inside `ownershipChipsRaw` rather than in a new field, so
/// none of this costs a CloudKit deploy. The property that makes that honest
/// is at the bottom: a build that predates the token still reads the string.
@MainActor
struct Build37ChipOrderTests {

    private func raw(_ order: OwnershipChipOrder, _ kinds: [Ownership]) -> String {
        ([order.storedToken].compactMap { $0 } + kinds.map(\.rawValue))
            .joined(separator: ",")
    }

    // MARK: Standard

    /// The default writes no token at all, so a library that never opens this
    /// setting stores exactly the string it stores today.
    @Test func standardWritesNoToken() {
        #expect(OwnershipChipOrder.standard.storedToken == nil)
        #expect(raw(.standard, [.digital, .physical]) == "digital,physical")
    }

    /// …and is still read in the app's order, whatever order it was written in.
    @Test func standardIgnoresTheStoredOrder() {
        let chips = ThemePalette.chips(from: "rented,digital,physical")
        #expect(chips == [.physical, .digital, .rented])
    }

    // MARK: Custom

    @Test func customKeepsTheOrderYouDragged() {
        let stored = raw(.custom, [.digital, .subscription, .previouslyOwned, .physical])
        #expect(ThemePalette.chipOrder(from: stored) == .custom)
        #expect(ThemePalette.chips(from: stored)
                == [.digital, .subscription, .previouslyOwned, .physical])
    }

    /// A chip the stored order does not mention — turned on by an older build,
    /// or a case added since — lands at the end rather than vanishing.
    @Test func aChipMissingFromTheOrderIsStillShown() {
        // `emulated` is in the set but not named before the others.
        let stored = "order=custom,digital,physical,emulated"
        #expect(ThemePalette.chips(from: stored) == [.digital, .physical, .emulated])
    }

    // MARK: Most used

    @Test func mostUsedPutsTheCommonestFirst() {
        ThemePalette.refreshOwnershipUsage(from: [])
        let stored = raw(.mostUsed, [.physical, .digital, .subscription])
        // With nothing counted it falls back to the app's own order rather
        // than to an arbitrary one.
        #expect(ThemePalette.chips(from: stored) == [.physical, .digital, .subscription])
    }

    @Test func tiesFallBackToTheAppsOrder() {
        var library: [Game] = []
        for _ in 0..<3 {
            let g = Game(name: "s")
            g.ownership = [Ownership.subscription.rawValue]
            library.append(g)
        }
        let d = Game(name: "d")
        d.ownership = [Ownership.digital.rawValue]
        library.append(d)
        // physical and emulated are both unused, so they tie at zero.
        ThemePalette.refreshOwnershipUsage(from: library)

        let stored = raw(.mostUsed, [.physical, .digital, .emulated, .subscription])
        #expect(ThemePalette.chips(from: stored)
                == [.subscription, .digital, .physical, .emulated])
        ThemePalette.refreshOwnershipUsage(from: [])
    }

    // MARK: The property the whole storage trick rests on

    /// **A build that has never heard of the token still reads the string.**
    ///
    /// This reproduces the old parser exactly: split on commas, keep the
    /// entries that are valid raw values, drop the rest. The token is not a
    /// valid `Ownership`, so it falls out and the chip SET is unchanged —
    /// which is why this needed no schema deploy.
    @Test func anOlderBuildReadsTheSetAndIgnoresTheToken() {
        let stored = raw(.custom, [.digital, .subscription, .physical])
        let asOldBuildSawIt = Set(stored.split(separator: ",").map(String.init))
        let resolved = Ownership.allCases.filter { asOldBuildSawIt.contains($0.rawValue) }
        #expect(resolved == [.physical, .digital, .subscription])
        // The token is in the string and is not a chip, which is exactly why
        // the old parser drops it instead of choking on it.
        #expect(asOldBuildSawIt.contains("order=custom"))
        #expect(Ownership(rawValue: "order=custom") == nil)
    }

    /// An unknown order value is not a crash and not an empty row.
    @Test func anUnknownOrderFallsBackToStandard() {
        #expect(ThemePalette.chipOrder(from: "order=byVibes,digital,physical") == .standard)
        #expect(ThemePalette.chips(from: "order=byVibes,digital,physical")
                == [.physical, .digital])
    }

    /// Turning everything off still leaves a usable row.
    @Test func anEmptySetFallsBackToTheDefaults() {
        #expect(ThemePalette.chips(from: "order=custom") == Ownership.shownByDefault)
    }
}
