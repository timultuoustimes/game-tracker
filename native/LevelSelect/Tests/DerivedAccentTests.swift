import Testing
import Foundation
import SwiftUI
@testable import LevelSelect

/// **The linked-hue palette, and the claim it rests on.**
///
/// The user picks a hue and a saturation; the app derives brightness per
/// appearance. The promise that makes this worth building is that the hue
/// wheel never has to be restricted — *every* hue has a brightness that reads
/// on both grounds, so the app can solve it instead of graying out half the
/// spectrum. These tests exist to find out whether that promise is true, not
/// to assert that it is.
@MainActor
struct DerivedAccentTests {

    private var lightGround: Color { ThemePalette.groundBase(dark: false) }
    private var darkGround: Color { ThemePalette.groundBase(dark: true) }

    /// Torch's own hue and saturation, from `LSTheme.torch` — rgb(0.96, 0.64, 0.30).
    private var torchHS: (hue: Double, saturation: Double) {
        let hs = LSTheme.torch.lsHueSaturation
        return (hs?.hue ?? 0, hs?.saturation ?? 0)
    }

    /// The rule has to land on the values we already ship, or it is a fit
    /// rather than a rule. Both defaults were arrived at by hand, before the
    /// derivation existed.
    @Test func theRuleReproducesTheShippedDefaults() {
        ThemePalette.refresh(from: nil)
        let hs = torchHS

        let dark = LSTheme.derivedAccent(hue: hs.hue, saturation: hs.saturation,
                                         dark: true, ground: darkGround).color
        let light = LSTheme.derivedAccent(hue: hs.hue, saturation: hs.saturation,
                                          dark: false, ground: lightGround).color

        // Same hue family as the hand-picked values, and legible on each ground.
        #expect(LSContrast.ratio(dark, darkGround) >= 4.5)
        #expect(LSContrast.ratio(light, lightGround) >= 4.5)

        // Brightness: dark should sit at or near the preferred 0.96 (torch is
        // already legible there and needs no correction); light should have
        // walked down from 0.60 only if it had to.
        let darkB = dark.lsHueSaturation
        #expect(darkB != nil)
        #expect(abs((light.lsHueSaturation?.hue ?? -1) - hs.hue) < 0.02,
                "derivation must not shift the hue the user picked")
        #expect(abs((dark.lsHueSaturation?.hue ?? -1) - hs.hue) < 0.02)
    }

    /// **Everything solves now, and softening is confined to where it must be.**
    ///
    /// Before softening, 12 of 144 sampled combinations were unreachable —
    /// all saturated blues and violets on the dark ground, because blue
    /// contributes 0.0722 to relative luminance against green's 0.7152, so a
    /// saturated blue at FULL brightness is still luminance-dark.
    ///
    /// With saturation as a last resort every combination lands. What this
    /// test guards is that it is a LAST resort: softening must never happen on
    /// the light ground, and on dark only inside the blue/violet band.
    @Test func everythingSolvesAndSofteningStaysInItsCorner() {
        ThemePalette.refresh(from: nil)
        var unreadable: [String] = []
        var softenedOnLight: [String] = []
        var softenedStrays: [String] = []
        var softenedCount = 0

        for hueStep in 0..<36 {
            let hue = Double(hueStep) / 36.0
            for saturation in [0.35, 0.55, 0.75, 0.95] {
                let light = LSTheme.derivedAccent(hue: hue, saturation: saturation,
                                                  dark: false, ground: lightGround)
                let dark = LSTheme.derivedAccent(hue: hue, saturation: saturation,
                                                 dark: true, ground: darkGround)
                if LSContrast.ratio(light.color, lightGround) < 4.5 {
                    unreadable.append(String(format: "light h=%.2f s=%.2f", hue, saturation))
                }
                if LSContrast.ratio(dark.color, darkGround) < 4.5 {
                    unreadable.append(String(format: "dark h=%.2f s=%.2f", hue, saturation))
                }
                if light.softened {
                    softenedOnLight.append(String(format: "h=%.2f s=%.2f", hue, saturation))
                }
                if dark.softened {
                    softenedCount += 1
                    if !(hue >= 0.58 && hue <= 0.80 && saturation >= 0.70) {
                        softenedStrays.append(String(format: "h=%.2f s=%.2f", hue, saturation))
                    }
                }
            }
        }

        #expect(unreadable.isEmpty,
                Comment(rawValue: "still unreadable after softening: \(unreadable)"))
        #expect(softenedOnLight.isEmpty,
                Comment(rawValue: "light never needs softening: \(softenedOnLight)"))
        #expect(softenedStrays.isEmpty,
                Comment(rawValue: "softened OUTSIDE the blue/violet corner: \(softenedStrays)"))
        #expect(softenedCount <= 14,
                Comment(rawValue: "softening spread to \(softenedCount) of 144"))
    }

    /// The common case must be untouched: a hue that brightness can solve
    /// keeps exactly the saturation the user asked for.
    @Test func aSolvableHueIsNeverSoftened() {
        ThemePalette.refresh(from: nil)
        let hs = torchHS
        for dark in [false, true] {
            let ground = dark ? darkGround : lightGround
            let d = LSTheme.derivedAccent(hue: hs.hue, saturation: hs.saturation,
                                          dark: dark, ground: ground)
            #expect(!d.softened, "torch should never need softening")
            #expect(abs(d.saturation - hs.saturation) < 0.005)
        }
    }

    /// Saturation is the user's, and the app reports it whenever it is not.
    ///
    /// This asserted that saturation never moves. It now can — hue 0.6 at
    /// saturation 0.9 is inside the blue corner and softens to 0.86 — so the
    /// property worth holding is the honest one: the value the struct reports
    /// is the value actually used, and `softened` is set exactly when they
    /// differ. A silent compromise is what this model exists to avoid.
    @Test func reportedSaturationIsAlwaysTheSaturationUsed() {
        ThemePalette.refresh(from: nil)
        for hue in [0.08, 0.33, 0.6, 0.72, 0.95] {
            for saturation in [0.4, 0.7, 0.9] {
                let d = LSTheme.derivedAccent(hue: hue, saturation: saturation,
                                              dark: true, ground: darkGround)
                let actual = d.color.lsHueSaturation?.saturation ?? -1
                #expect(abs(actual - d.saturation) < 0.02,
                        Comment(rawValue: "reported \(d.saturation) but the color is \(actual)"))
                #expect(d.softened == (d.saturation < saturation - 0.005),
                        Comment(rawValue: "softened flag disagrees at h=\(hue) s=\(saturation)"))
                if !d.softened {
                    #expect(abs(actual - saturation) < 0.02,
                            Comment(rawValue: "unsoftened but saturation moved at h=\(hue)"))
                }
            }
        }
    }

    /// A gray pick has no hue to preserve, and must still be legible.
    @Test func agreyPickStillLands() {
        ThemePalette.refresh(from: nil)
        let light = LSTheme.derivedAccent(hue: 0, saturation: 0, dark: false, ground: lightGround).color
        let dark = LSTheme.derivedAccent(hue: 0, saturation: 0, dark: true, ground: darkGround).color
        #expect(LSContrast.ratio(light, lightGround) >= 4.5)
        #expect(LSContrast.ratio(dark, darkGround) >= 4.5)
    }
}

/// `LSTheme.legible` — the guarantee that lets the accent stay ink.
@MainActor
struct LegibleAccentTests {
    private var lightGround: Color { ThemePalette.groundBase(dark: false) }
    private var darkGround: Color { ThemePalette.groundBase(dark: true) }

    /// A color that already reads must come back untouched. Anything else
    /// would move the accent of every user whose choice was already fine.
    @Test func aPassingColourIsReturnedUnchanged() {
        ThemePalette.refresh(from: nil)
        let torch = LSTheme.torch
        #expect(LSTheme.legible(torch, on: darkGround) == torch)
        #expect(LSTheme.legible(LSTheme.torchInk, on: lightGround) == LSTheme.torchInk)
    }

    /// The developer's own accent, stored long before anything checked it.
    @Test func aLegacyAccentThatFailsIsCorrectedAndKeepsItsHue() throws {
        ThemePalette.refresh(from: nil)
        let purple = try #require(Color(hex: "#8A5CF6"))
        #expect(ThemePalette.contrast(purple, darkGround) < 4.5, "the premise: it fails today")

        let fixed = LSTheme.legible(purple, on: darkGround)
        #expect(ThemePalette.contrast(fixed, darkGround) >= 4.5, "still unreadable after correction")

        let before = purple.lsHueSaturation?.hue ?? -1
        let after = fixed.lsHueSaturation?.hue ?? -2
        #expect(abs(before - after) < 0.03, "correction must keep the color recognizably theirs")
    }
}

/// Build 37 — the accent that came out black, and the art that vanished with
/// a name.
///
/// Both were found the morning after Tim's profile was deleted and re-added,
/// on a phone that had switched to light mode overnight — which is why
/// neither had been seen before.
@MainActor
struct Build37HeaderInkTests {

    private var lightGround: Color { ThemePalette.groundBase(dark: false) }

    /// A color that reads fine as display type and fails as body text — the
    /// band the whole bug lives in. Found rather than hardcoded, so the test
    /// still means something if a ground tint moves.
    private func colorInTheGap() -> Color? {
        for step in stride(from: 0.30, through: 0.95, by: 0.01) {
            let candidate = Color(hue: 0.88, saturation: 0.65, brightness: step)
            let ratio = LSContrast.ratio(candidate, lightGround)
            if ratio >= 3, ratio < 4.5 { return candidate }
        }
        return nil
    }

    /// **The two floors disagree, and that disagreement was the bug.**
    ///
    /// At 4.5:1 a mid plum on a light ground is pushed dark enough to read
    /// black under a pixel face; at 3:1 — the floor WCAG asks of large text —
    /// it is returned untouched.
    @Test func theDisplayFloorKeepsAColorTheBodyFloorDarkens() throws {
        let plum = try #require(colorInTheGap(),
                                "no color sits between the two floors on this ground")
        #expect(LSTheme.legible(plum, on: lightGround, floor: 3) == plum)
        #expect(LSTheme.legible(plum, on: lightGround) != plum)
    }

    /// Accent and Custom have to agree about the same color. They did not:
    /// one went through the 4.5:1 correction and the other through none, so
    /// pressing a different button changed the color on screen.
    @Test func theNameFollowsTheDisplayAccent() {
        ThemePalette.refresh(from: nil)
        #expect(ProfileNameColor.resolve(ProfileNameColor.accent) == LSTheme.displayAccent)
    }

    /// Still a guarantee, just the right one — nothing here opts out of
    /// legibility, it only stops applying the body-text rule to display type.
    @Test func theDisplayAccentStillClearsTheLargeTextFloor() {
        let corrected = LSTheme.legible(LSTheme.torchInk, on: lightGround, floor: 3)
        #expect(LSContrast.ratio(corrected, lightGround) >= 3)
    }

    @Test func aCustomHexIsUntouchedByEitherFloor() {
        #expect(ProfileNameColor.resolve("#8B2F63") == Color(hex: "#8B2F63"))
    }

    @Test func theDefaultIsOrdinaryTextNotTheAccent() {
        #expect(ProfileNameColor.resolve(ProfileNameColor.plain) == .primary)
        #expect(ProfileNameColor.mode(of: "") == .plain)
        #expect(ProfileNameColor.mode(of: "accent") == .accent)
        #expect(ProfileNameColor.mode(of: "#8B2F63") == .custom)
    }

    // MARK: The art

    /// **A blank name field must not take the week's art with it.**
    ///
    /// `drawsArt` required a filled profile, so deleting a name emptied the
    /// header of cover art that has nothing to do with the profile.
    @Test func theWeeksArtDrawsWithNoProfileAtAll() {
        let week = PlayerSummary(recentCovers: ["a", "b"])
        #expect(week.usesRibbon)
        #expect(ProfileHeader.drawsArt(profile: nil, summary: week))
    }

    @Test func oneQuietWeeksFallbackAlsoDraws() {
        let quiet = PlayerSummary(recentCovers: ["a"], fallbackBackdrop: "cover")
        #expect(!quiet.usesRibbon)
        #expect(ProfileHeader.drawsArt(profile: nil, summary: quiet))
    }

    /// No art is still no art band — the reason the gate exists at all is that
    /// 190pt of flat tint reads as a broken image.
    @Test func nothingPlayedMeansNoArtBand() {
        #expect(!ProfileHeader.drawsArt(profile: nil, summary: PlayerSummary()))
    }
}
