import Testing
import Foundation
import SwiftData
@testable import LevelSelect

/// A cover you chose yourself has to appear on the shelves, not only on the
/// game page.
///
/// `ArtworkPointer` stores a picked photo as `levelselect-image:<id>`, and
/// `Game.displayCoverURLString` returns nil for that deliberately — it will
/// not substitute the fetched cover for the one you actually picked. Every
/// shelf, list and strip then asked `CoverThumb` to load a URL, got nil, and
/// drew the placeholder. The game page was the only surface that showed the
/// picture, because it goes through `resolvedArtwork` instead.
///
/// So the contract worth pinning is the pair: `displayCoverURLString` stays
/// nil (that part is correct and load-bearing), and `resolvedArtwork(.cover)`
/// carries the bytes that the URL cannot. A shelf that reads only the first
/// one is the bug.
@MainActor
struct LocalCoverVisibilityTests {

    private func makeContext() -> ModelContext {
        ModelContext(LevelSelectStore.makeContainer(inMemory: true))
    }

    /// A 1×1 PNG — enough to be stored and pointed at.
    private let pixel = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!

    @Test func aPickedCoverIsInvisibleToAUrlOnlyReader() throws {
        let context = makeContext()
        let repo = Repository(context)
        let game = Game(name: "Hollow Knight")
        context.insert(game)

        let image = try repo.addImage(to: game, data: pixel, role: .cover)
        repo.setArtwork(image.pointer, role: .cover, on: game)

        // The URL accessor is nil on purpose, and that is exactly why a
        // URL-only shelf cannot draw this cover.
        #expect(game.displayCoverURLString == nil)
        // The bytes are reachable — a shelf just has to ask for them.
        guard case .local(let data) = game.resolvedArtwork(.cover) else {
            Issue.record("a picked cover should resolve as local artwork")
            return
        }
        #expect(!data.isEmpty)
    }

    /// A fetched cover is unaffected: the URL still leads, and there is no
    /// local artwork to prefer over it.
    @Test func aFetchedCoverStillTravelsAsAUrl() {
        let context = makeContext()
        let game = Game(name: "Hades")
        game.coverURLString = "https://images.igdb.com/hades.jpg"
        context.insert(game)

        #expect(game.displayCoverURLString == "https://images.igdb.com/hades.jpg")
        // Nothing local to prefer, so the shelf falls through to the URL it
        // has always used.
        if case .local = game.resolvedArtwork(.cover) {
            Issue.record("a fetched cover should not resolve as local artwork")
        }
    }

    /// A picked cover wins over a fetched one — the precedence the shelf now
    /// applies has to match the precedence `displayCoverURLString` already
    /// applied, or the two surfaces disagree about which picture is yours.
    @Test func aPickedCoverBeatsAFetchedOne() throws {
        let context = makeContext()
        let repo = Repository(context)
        let game = Game(name: "Celeste")
        game.coverURLString = "https://images.igdb.com/celeste.jpg"
        context.insert(game)

        let image = try repo.addImage(to: game, data: pixel, role: .cover)
        repo.setArtwork(image.pointer, role: .cover, on: game)

        #expect(game.displayCoverURLString == nil)
        if case .local = game.resolvedArtwork(.cover) {} else {
            Issue.record("the picked cover should win over the fetched URL")
        }
    }
}
