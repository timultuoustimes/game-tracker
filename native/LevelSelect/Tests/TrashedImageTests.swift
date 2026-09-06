import Testing
import Foundation
import SwiftData
@testable import LevelSelect

/// Recently Deleted, for pictures.
///
/// `restore(_ image:)` existed for two schema versions and nothing called it,
/// so a removed picture was tombstoned, invisible, and holding its full-size
/// bytes forever. Tim: *"Photos need to show up in recently deleted and have a
/// way to be actually deleted."* Codex data #4.
@MainActor
struct TrashedImageTests {

    private func store() -> Repository {
        Repository(ModelContext(LevelSelectStore.makeContainer(inMemory: true)))
    }

    private func picture(_ repo: Repository, on game: Game) -> GameImage {
        let image = GameImage(data: Data(repeating: 7, count: 128))
        repo.context.insert(image)
        image.game = game
        return image
    }

    @Test func aRemovedPictureAppearsInTheTrash() {
        let repo = store()
        let game = repo.addGame(name: "Hollow Knight", status: .playing)
        let image = picture(repo, on: game)

        #expect(repo.trashedImages().isEmpty)
        repo.softDelete(image)
        #expect(repo.trashedImages().count == 1)
    }

    @Test func restoringPutsItBack() {
        let repo = store()
        let game = repo.addGame(name: "Hollow Knight", status: .playing)
        let image = picture(repo, on: game)
        repo.softDelete(image)

        repo.restore(image)

        #expect(image.deletedAt == nil)
        #expect(repo.trashedImages().isEmpty)
    }

    /// The point of the whole fix: the bytes actually go.
    @Test func deletingForeverRemovesTheRow() {
        let repo = store()
        let game = repo.addGame(name: "Hollow Knight", status: .playing)
        let image = picture(repo, on: game)
        repo.softDelete(image)

        repo.deleteForever(image)

        #expect(repo.trashedImages().isEmpty)
        let all = (try? repo.context.fetch(FetchDescriptor<GameImage>())) ?? []
        #expect(all.isEmpty)
    }

    /// A picture on a memory with no game at all — the case that "delete the
    /// whole game forever" could never reach, and the reason this needed its
    /// own path rather than a cascade.
    @Test func aPictureOnAGamelessMemoryIsReachable() {
        let repo = store()
        let memory = Memory(title: "First LAN party")
        repo.context.insert(memory)
        let image = GameImage(data: Data(repeating: 3, count: 64))
        repo.context.insert(image)
        image.memory = memory

        repo.softDelete(image)
        #expect(repo.trashedImages().count == 1)

        repo.deleteForever(image)
        #expect(repo.trashedImages().isEmpty)
    }

    /// Pictures under a trashed GAME stay out of the list: they come back with
    /// it, and offering to restore one onto a game that isn't there is an
    /// offer the app cannot keep.
    @Test func picturesUnderATrashedGameAreNotListedSeparately() {
        let repo = store()
        let game = repo.addGame(name: "Hollow Knight", status: .playing)
        let image = picture(repo, on: game)
        repo.softDelete(image)
        repo.softDelete(game)

        #expect(repo.trashedImages().isEmpty)
        #expect(repo.trashedGames().count == 1)
    }
}

/// Permanently deleting a game takes its id out of every collection.
///
/// Membership is a scalar id rather than a relationship, so nothing cascaded
/// it — a collection kept a string pointing at a row that no longer existed.
/// Reads filtered it away, so it was invisible rather than broken, which is
/// exactly the kind of wrongness that surfaces years later in an export.
/// Codex data open question 8; Tim: *"yes"*.
@MainActor
struct CollectionScrubTests {

    @Test func permanentDeletionRemovesTheGameFromItsCollections() {
        let context = ModelContext(LevelSelectStore.makeContainer(inMemory: true))
        let repo = Repository(context)
        let game = repo.addGame(name: "Hollow Knight", status: .playing)
        let keeper = repo.addGame(name: "Hades", status: .playing)
        let collection = repo.createCollection(name: "Comfort Games")
        repo.setMembership(collection, game: game, member: true)
        repo.setMembership(collection, game: keeper, member: true)
        #expect(collection.gameIDs.count == 2)

        repo.softDelete(game)
        repo.deleteForever(game)

        #expect(collection.gameIDs == [keeper.id.uuidString])
    }

    /// A soft delete must NOT scrub it: the game is coming back, and it should
    /// come back to the collections it was in.
    @Test func aSoftDeleteLeavesMembershipAlone() {
        let context = ModelContext(LevelSelectStore.makeContainer(inMemory: true))
        let repo = Repository(context)
        let game = repo.addGame(name: "Hollow Knight", status: .playing)
        let collection = repo.createCollection(name: "Comfort Games")
        repo.setMembership(collection, game: game, member: true)

        repo.softDelete(game)

        #expect(collection.gameIDs == [game.id.uuidString])
        repo.restore(game)
        #expect(collection.contains(game))
    }
}
