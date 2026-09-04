import Foundation
import SwiftData

/// Mutable per-playthrough progress for one schema item (sparse). CloudKit-compatible.
@Model
final class TrackerStateRecord {
    var id: UUID = UUID()
    var userID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var revision: Int = 0
    var deletedAt: Date?
    var legacyID: String?

    var itemID: String = ""          // stable id of the schema item
    var completed: Bool = false
    /// When this item was ticked — set on completion, cleared on un-tick.
    ///
    /// Distinct from `updatedAt`, which moves for any change at all: adding a
    /// note or un-ticking something from years ago would make that item look
    /// like the most recent thing you did. "Where you left off" needs the
    /// moment you finished it, not the moment the row last changed. Nil on
    /// rows written before this field existed, which read as `updatedAt`.
    var completedAt: Date?
    var count: Int?
    var rank: Int?
    var revealed: Bool = false
    var notes: String?
    /// Which alternative of a multi-variant item the user picked (Hades' Mirror
    /// of Night talents have an "Alt:" form). Schema V2 — the chip only
    /// reveals the alternative today; making it a real choice needed a field,
    /// and overloading `count`/`notes` was rejected as the kind of thing that
    /// bites later.
    var selectedVariant: String?
    /// When `selectedVariant` was last set — including being set back to nil.
    ///
    /// **Storage only in build 37; the reconciler does not read it yet.**
    /// Scaffolded now because it needs a CloudKit deploy and the appearance
    /// palette needed one anyway. Two offline devices can each create a state
    /// row for the same item, and `mergeDuplicateStates` keeps one and
    /// tombstones the rest without ever looking at `selectedVariant` — so a
    /// chosen Mirror talent disappears. Copying a nonnil loser is not the fix
    /// either: nil can mean "I deliberately switched back to default", and
    /// without a timestamp the merge cannot tell that from never-set.
    var selectedVariantUpdatedAt: Date?

    var playthrough: Playthrough?

    init(
        id: UUID = UUID(),
        itemID: String,
        completed: Bool = false,
        count: Int? = nil,
        rank: Int? = nil,
        revealed: Bool = false
    ) {
        self.id = id
        self.createdAt = .now
        self.updatedAt = .now
        self.itemID = itemID
        self.completed = completed
        self.count = count
        self.rank = rank
        self.revealed = revealed
    }
}

extension TrackerStateRecord {
    /// The ONE duplicate-winner rule, shared by every reader — repository
    /// reads, the tracker view's state map, the widget bridge, progress
    /// recomputation, and the reconciler's fold. Total order: latest
    /// `updatedAt`, ties broken by id, so every device (and every reader on
    /// one device) resolves the same row. Round 3 found three readers each
    /// using a different arbitrary rule ("first in relationship order",
    /// "any twin completed"), which let a widget or a cached percentage
    /// contradict the repository's declared winner until reconciliation
    /// happened to run.
    func outranks(_ other: TrackerStateRecord) -> Bool {
        (updatedAt, id.uuidString) > (other.updatedAt, other.id.uuidString)
    }

    /// The winning row among duplicates for one item, under that total order.
    static func winner(of records: [TrackerStateRecord]) -> TrackerStateRecord? {
        records.max { $1.outranks($0) }
    }
}

extension TrackerStateRecord {
    /// When this counts as ticked. Rows written before `completedAt` existed
    /// fall back to `updatedAt`, which is the best they ever knew.
    var tickedAt: Date { completedAt ?? updatedAt }
}
