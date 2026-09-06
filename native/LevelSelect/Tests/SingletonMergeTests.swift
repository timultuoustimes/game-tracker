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
