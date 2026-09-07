import Testing
import Foundation
import SwiftData
@testable import LevelSelect

/// Two devices, two "single" records, and nothing lost when they meet.
///
/// `ThemeSettings` and `PlayerProfile` say "one record" and CloudKit has no
/// way to enforce it. `fetchOrCreate` resolved to the oldest — deterministic,
/// and still wrong, because the newer row is where the OTHER device's edits
/// are. Codex data #9; Tim, on how they should merge: *"per field."*
@MainActor
struct SingletonMergeTests {

    private func store() -> Repository {
        Repository(ModelContext(LevelSelectStore.makeContainer(inMemory: true)))
    }

    private func themes(_ repo: Repository) -> [ThemeSettings] {
        ((try? repo.context.fetch(FetchDescriptor<ThemeSettings>())) ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The exact loss the finding describes: an avatar set on one device and a
    /// palette on the other, and "oldest wins" throws one of them away.
    @Test func independentEditsOnTwoRowsBothSurvive() {
        let repo = store()
        let older = ThemeSettings()
        older.createdAt = .now.addingTimeInterval(-100)
        older.accentHex = "#FF0000"
        repo.context.insert(older)

        let newer = ThemeSettings()
        newer.createdAt = .now
        newer.updatedAt = .now.addingTimeInterval(50)
        newer.backgroundHexDark = "#101010"
        repo.context.insert(newer)

        #expect(repo.reconcileSingletons() == 1)
        let rows = themes(repo)
        #expect(rows.count == 1)
        #expect(rows.first?.accentHex == "#FF0000")
        #expect(rows.first?.backgroundHexDark == "#101010")
    }

    /// When BOTH rows set the same field, the newer edit wins — the only
    /// honest tiebreak without per-field causality.
    @Test func aRealConflictGoesToTheNewerEdit() {
        let repo = store()
        let older = ThemeSettings()
        older.createdAt = .now.addingTimeInterval(-100)
        older.updatedAt = .now.addingTimeInterval(-100)
        older.accentHex = "#FF0000"
        repo.context.insert(older)

        let newer = ThemeSettings()
        newer.createdAt = .now
        newer.updatedAt = .now
        newer.accentHex = "#00FF00"
        repo.context.insert(newer)

        _ = repo.reconcileSingletons()
        #expect(themes(repo).first?.accentHex == "#00FF00")
    }

    /// The surviving row is the one `fetchOrCreate` already returns, so
    /// nothing holding a reference to it is invalidated by the fold.
    @Test func theOldestRowIsTheOneThatSurvives() {
        let repo = store()
        let older = ThemeSettings()
        older.createdAt = .now.addingTimeInterval(-100)
        repo.context.insert(older)
        let newer = ThemeSettings()
        newer.createdAt = .now
        repo.context.insert(newer)

        _ = repo.reconcileSingletons()
        #expect(themes(repo).first === older)
        #expect(ThemePalette.fetchOrCreate(in: repo.context) === older)
    }

    @Test func oneRowIsNotAConflictAndIsNotTouched() {
        let repo = store()
        let only = ThemeSettings()
        only.accentHex = "#ABCDEF"
        repo.context.insert(only)

        #expect(repo.reconcileSingletons() == 0)
        #expect(themes(repo).count == 1)
        #expect(themes(repo).first?.accentHex == "#ABCDEF")
    }

    @Test func profilesMergeTheSameWay() {
        let repo = store()
        let older = PlayerProfile()
        older.createdAt = .now.addingTimeInterval(-100)
        older.displayName = "Tim"
        repo.context.insert(older)

        let newer = PlayerProfile()
        newer.createdAt = .now
        newer.updatedAt = .now.addingTimeInterval(50)
        newer.avatarData = Data(repeating: 4, count: 32)
        repo.context.insert(newer)

        #expect(repo.reconcileSingletons() == 1)
        let rows = ((try? repo.context.fetch(FetchDescriptor<PlayerProfile>())) ?? [])
        #expect(rows.count == 1)
        #expect(rows.first?.displayName == "Tim")
        #expect(rows.first?.avatarData?.count == 32)
    }

    /// **All five authored fields, not three.**
    ///
    /// The fold copied `displayName`, `avatarData` and `handlesData` and left
    /// `nameColorRaw` and `useHandleAsName` behind — then deleted the row that
    /// held them. Codex found it on 2026-09-07; the exact trigger is a second
    /// device that links its name to a handle and picks a name color.
    @Test func aNameColorAndAHandleLinkSurviveTheFold() {
        let repo = store()
        let older = PlayerProfile()
        older.createdAt = .now.addingTimeInterval(-100)
        older.displayName = "Tim"
        repo.context.insert(older)

        let newer = PlayerProfile()
        newer.createdAt = .now
        newer.updatedAt = .now.addingTimeInterval(50)
        newer.nameColorRaw = "#8B2F63"
        newer.useHandleAsName = true
        newer.handles = ["steam": "timultuoustimes"]
        repo.context.insert(newer)

        #expect(repo.reconcileSingletons() == 1)
        let rows = ((try? repo.context.fetch(FetchDescriptor<PlayerProfile>())) ?? [])
        #expect(rows.count == 1)
        let kept = rows.first
        #expect(kept?.displayName == "Tim")
        #expect(kept?.nameColorRaw == "#8B2F63")
        #expect(kept?.useHandleAsName == true)
        #expect(kept?.handles["steam"] == "timultuoustimes")
    }

    /// A name color already chosen is not replaced by the loser's — identity
    /// fields fill blanks, they do not take the newer value.
    @Test func anExistingNameColorIsNotOverwritten() {
        let repo = store()
        let older = PlayerProfile()
        older.createdAt = .now.addingTimeInterval(-100)
        older.nameColorRaw = "accent"
        repo.context.insert(older)

        let newer = PlayerProfile()
        newer.createdAt = .now
        newer.updatedAt = .now.addingTimeInterval(50)
        newer.nameColorRaw = "#00FF00"
        repo.context.insert(newer)

        #expect(repo.reconcileSingletons() == 1)
        #expect((try? repo.context.fetch(FetchDescriptor<PlayerProfile>()))?
                    .first?.nameColorRaw == "accent")
    }

    /// **The winner cannot depend on a coin flip.**
    ///
    /// Both folds passed `{ _ in UUID() }` as the tie-break, so rows created in
    /// the same instant sorted at random inside the comparator. Two devices
    /// doing that could keep different rows and delete each other's winner.
    @Test func rowsCreatedInTheSameInstantFoldTheSameWayEveryTime() {
        let instant = Date.now
        var survivors: [String] = []
        for _ in 0..<8 {
            let repo = store()
            for name in ["a", "b", "c"] {
                let p = PlayerProfile()
                p.createdAt = instant
                p.id = UUID(uuidString: "0000000\(name == "a" ? 1 : name == "b" ? 2 : 3)-0000-0000-0000-000000000000")!
                p.displayName = name
                repo.context.insert(p)
            }
            _ = repo.reconcileSingletons()
            survivors.append(
                ((try? repo.context.fetch(FetchDescriptor<PlayerProfile>())) ?? [])
                    .first?.displayName ?? "?")
        }
        #expect(Set(survivors).count == 1, "fold picked \(Set(survivors)) across runs")
        #expect(survivors.first == "a")
    }

    /// Three rows fold to one, not to two — the sweep has to be complete or a
    /// later launch does it again with different content.
    @Test func threeRowsFoldToOne() {
        let repo = store()
        for i in 0..<3 {
            let t = ThemeSettings()
            t.createdAt = .now.addingTimeInterval(Double(i) * -10)
            repo.context.insert(t)
        }
        #expect(repo.reconcileSingletons() == 2)
        #expect(themes(repo).count == 1)
    }
}
