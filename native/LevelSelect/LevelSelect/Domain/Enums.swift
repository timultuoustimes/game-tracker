import Foundation

// MARK: - Domain enums (see native/DOMAIN-MODEL.md)
// All String-raw for direct SwiftData attribute storage.

/// Legacy `status` — 7 values verified against the frozen library — plus
/// `wishlist` (added 2026-08: games not yet owned, promoted from Deku Deals)
/// and `ongoing` (added 2026-08: games with no finish line).
///
/// Adding a case costs no schema version: this is stored as a String
/// attribute, so the shape on disk and in CloudKit is unchanged.
enum GameStatus: String, Codable, CaseIterable, Sendable {
    /// `oldFavorite` is build 36. Free to add — a new case in a String-raw
    /// enum needs no schema version, the same path `wishlist` and `ongoing`
    /// took.
    case backlog, playing, paused, completed, queued, shelved, abandoned,
         wishlist, ongoing, oldFavorite

    /// What each one MEANS, in one line, shown where you choose it.
    ///
    /// Nine statuses shipped without this and the cost showed up in the
    /// obvious way: asked to list the ones that did not fit his childhood
    /// games, Tim named four and did not mention `shelved` at all — a status
    /// he had designed. If the author loses track of one, nobody else stands
    /// a chance.
    ///
    /// A blurb rather than a "status key" page, because a key is something you
    /// have to go and find, and the moment you need the meaning is the moment
    /// you are choosing. `PlaythroughOutcome` already does exactly this.
    ///
    /// These are the app's meaning, not the last word — `ThemeSettings
    /// .statusNames` lets anyone disagree.
    var blurb: String {
        switch self {
        case .playing:     "You're in it now."
        case .ongoing:     "No ending to reach — you just play it."
        case .paused:      "Mid-run, and you mean to go back."
        case .queued:      "Next up, once you have room."
        case .backlog:     "Yours, and not started yet."
        case .wishlist:    "Not yours yet."
        case .completed:   "You finished it."
        // The one this set was missing, and it is the ONLY status that does
        // not sit on the progress axis at all.
        //
        // `ongoing` escapes that axis by saying no finish line exists —
        // Minecraft, a city builder. This one escapes differently: the finish
        // line **exists and is beside the point**. That is why it has to stay
        // silent on whether you reached it. Tim's two examples are the whole
        // argument, and they sit at opposite ends of the old axis:
        //
        //   Sonic 2         beaten, and he will beat it again
        //   Awesome Possum  never beaten, and never will be
        //
        // Same relationship. Filing the first under Completed and the second
        // under Abandoned would split one feeling in half and call the second
        // one a failure. So the blurb is deliberately parallel to `ongoing`'s
        // — the two off-axis statuses should read as the pair they are.
        case .oldFavorite: "It has an ending — you'll play it again anyway."
        case .shelved:     "Set aside, no plans either way."
        case .abandoned:   "It lost you, and you're not going back."
        }
    }
}

enum SessionState: String, Codable, Sendable {
    case running, paused, stopped
}

/// How you own a game. Multi-select (a game can be owned physically AND
/// digitally); stored on `Game.ownership` as an array of raw values.
///
/// `previouslyOwned` records a copy that's gone — sold, traded, lent and
/// never returned. A lifetime library holds games you no longer hold, and
/// before this case the only honest options were pretending you still owned
/// it or deleting the history. New case in a String-raw enum = no schema
/// version, the same free path `wishlist` and `ongoing` took.
/// The order the ownership chips stand in, everywhere at once.
///
/// **Stored inside `ownershipChipsRaw`, so this costs no schema deploy.**
/// That field is an app-owned comma list, and an entry that is not a valid
/// `Ownership` raw value has always been dropped on the way in — so a build
/// that predates this reads `order=custom,digital,physical` as the set
/// {digital, physical} in its own order and behaves exactly as it did before.
/// A new field on `ThemeSettings` would have meant seeding, a Console diff and
/// a deploy to Production for what is a sentence about presentation.
///
/// `standard` writes no token at all, so a library that never touches this
/// stores the same string it stores today.
enum OwnershipChipOrder: String, CaseIterable, Identifiable, Sendable {
    /// The app's own order. Selections land differently on every game, which
    /// is the variety Tim wanted kept as the default.
    case standard
    /// Commonest in YOUR library first, counted across the games you have.
    case mostUsed
    /// Whatever you dragged it to.
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Standard"
        case .mostUsed: "Most used"
        case .custom:   "Custom"
        }
    }

    var blurb: String {
        switch self {
        case .standard: "The app's own order."
        case .mostUsed: "Commonest in your library first. Changes as the library does."
        case .custom:   "Drag them into the order you want."
        }
    }

    static let token = "order="

    init(token raw: String?) {
        guard let raw, raw.hasPrefix(Self.token),
              let parsed = OwnershipChipOrder(
                rawValue: String(raw.dropFirst(Self.token.count)))
        else { self = .standard; return }
        self = parsed
    }

    /// Nil for `standard`, so the stored string stays byte-identical to what
    /// every existing library already holds.
    var storedToken: String? { self == .standard ? nil : "\(Self.token)\(rawValue)" }
}

enum Ownership: String, Codable, CaseIterable, Sendable {
    // `previouslyOwned` keeps its raw value forever — it is what is stored in
    // every library already. Only the LABEL changed.
    case physical, digital, emulated, subscription, rented, previouslyOwned

    /// **Six chips, six single words, and they all finish the same sentence.**
    ///
    /// Each label is an adjective modifying an implied "copy" — a physical
    /// copy, a digital copy, an emulated copy, a subscription copy, a rented
    /// copy, a former copy. That is what makes them a set rather than four of
    /// one kind and one of another, and it is why "Previously owned" had to
    /// go: it was the only one that was a sentence about you instead of a
    /// description of the copy.
    ///
    /// **Rented is not subscription**, and Tim is right that the difference is
    /// worth a chip: *"Rented is something people can't do now, since those
    /// places are all closed... Closest analog now is subscription, but that's
    /// not the same as having walked into a Blockbuster and picking a game off
    /// the shelf to rent for the weekend."* A subscription is a catalog you
    /// pay for monthly; a rental was one game, for a weekend, that you took
    /// back. For a library that reaches back thirty years, that is a real
    /// distinction and not a nostalgic one — and it is off by default, because
    /// most people's libraries will never need it.
    ///
    /// "Former" over "Past", which reads as *past games* — finished ones — in
    /// an app that also tracks whether you beat something. Over "Sold", which
    /// is only one of the ways a game leaves. Over "Gone", which is true but
    /// sounds like a loss rather than a record.
    var label: String {
        switch self {
        case .physical: "Physical"
        case .digital:  "Digital"
        case .emulated: "Emulated"
        case .subscription: "Subscription"
        case .rented: "Rented"
        case .previouslyOwned: "Former"
        }
    }

    /// Shown unless someone turns them off. Rented is the exception — a
    /// weekend rental is a real thing that happened to a lot of libraries and
    /// a thing most libraries will never record, so it is opt-in rather than a
    /// sixth chip everyone has to look past.
    static let shownByDefault: [Ownership] =
        [.physical, .digital, .emulated, .subscription, .previouslyOwned]

    var systemImage: String {
        switch self {
        case .physical: "opticaldisc"
        case .digital:  "arrow.down.circle"
        case .emulated: "cpu"
        // It renews, and it stops when you stop paying — which is the whole
        // difference between this and `digital`, and the reason it earns its
        // own chip rather than hiding inside one.
        case .subscription: "arrow.triangle.2.circlepath"
        // A ticket: you had it for a while and it went back.
        case .rented: "ticket"
        case .previouslyOwned: "shippingbox"
        }
    }
}

/// Completion event label. `.custom` pairs with `CompletionEvent.customLabel`
/// (kept as a sibling String to avoid associated-value enums in SwiftData).
enum CompletionLabel: String, Codable, CaseIterable, Sendable {
    case completed, hundredPercent, newGamePlus, cleared, custom
}

enum TrackerSource: String, Codable, Sendable {
    case builtIn, aiGenerated
    /// Authored content brought in from a real source — RetroAchievements
    /// today. A String-raw case costs nothing (the "ongoing" status rule);
    /// what it buys is the record agreeing with the badge: the UI has said
    /// "RetroAchievements" since the badge shipped while the DATA said an AI
    /// made it, and an export that claims Claude wrote Nintendo's achievement
    /// list is the kind of lie this app exists to not tell.
    case imported
}

enum TrackerEngine: String, Codable, Sendable {
    case objective, run
}

enum RunOutcome: String, Codable, Sendable {
    case inProgress, success, failure, neutral
}

enum MapKind: String, Codable, Sendable {
    case world, area, other
}

enum MarkerCategory: String, Codable, CaseIterable, Sendable {
    case collectible, note, warning, secret
}

enum SyncOpType: String, Codable, Sendable {
    case upsert, delete
}

/// How a game presents its tracker on the game page.
enum TrackerDisplay: String, Codable, CaseIterable, Sendable {
    case inline     // embedded sections (original)
    case compact    // playthrough card + dedicated tracker page/panel

    var label: String {
        switch self {
        case .inline: "Inline"
        case .compact: "Compact"
        }
    }
}

/// How a game page arranges its header.
///
/// Build 32 rebuilt the header around each game's own art, which is the right
/// default and is not what everyone wants on every game. The layout it
/// replaced was compact and quiet, and quiet is a legitimate preference
/// rather than a worse one — a shelf of four hundred games read at speed is a
/// different job from admiring one.
///
/// String-raw, so a future case costs no schema version. The FIELD holding it
/// on `ThemeSettings` did cost one; the cases won't.
enum GamePageLayout: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Build 32: art at full strength, cover and facts panel centered in it,
    /// the game's logo across the full width underneath.
    case showcase
    /// What the app had before: cover on the left, the facts beside it, the
    /// name as text, and the art faded well back because the words sit on it.
    case classic
    /// The box on a shelf: one large cover centered, everything else beneath
    /// it. The art stays well back here for the same reason it does in
    /// classic — the words sit on it — and because a backdrop competing with
    /// a 190pt cover of the same game is the one thing this layout must not do.
    case coverLed
    /// No art band at all. A small cover, the facts inline beside it, and the
    /// sections starting almost immediately — for a library read at speed
    /// rather than admired.
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .showcase: "Showcase"
        case .classic:  "Classic"
        case .coverLed: "Cover"
        case .compact:  "Compact"
        }
    }

    /// Shown under the picker, because "Showcase" and "Classic" describe
    /// nothing on their own.
    var blurb: String {
        switch self {
        case .showcase: "The game's art fills the top, with its logo underneath."
        case .classic:  "Cover beside the details, name as text, art kept well back."
        case .coverLed: "One large cover, centered, with everything else beneath it."
        case .compact:  "No art. Small cover, and the sections start right away."
        }
    }
}
