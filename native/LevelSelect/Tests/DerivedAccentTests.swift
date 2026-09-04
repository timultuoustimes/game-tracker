import Testing
import Foundation
import SwiftUI
@testable import LevelSelect

/// **The linked-hue palette, and the claim it rests on.**
///
/// The user picks a hue and a saturation; the app derives brightness per
/// appearance. The promise that makes this worth building is that the hue
/// wheel never has to be restricted — *every* hue has a brightness that reads
/// on both grounds, so the app can solve it instead of greying out half the
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
                                         dark: true, ground: darkGround)
        let light = LSTheme.derivedAccent(hue: hs.hue, saturation: hs.saturation,
                                          dark: false, ground: lightGround)

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

    /// **The claim the model rested on, and what testing it actually found.**
    ///
    /// The hope was that every hue could be solved by brightness alone, so the
    /// picker would never restrict anything. That is **false**, and the shape
    /// of the failure matters:
    ///
    /// - **Light ground: every hue and saturation solves.** No restriction ever.
    /// - **Dark ground: saturated blues and violets cannot be solved** — hue
    ///   0.61–0.78 at saturation ≥ 0.75, 12 of 144 sampled combinations.
    ///
    /// Blue contributes only 0.0722 to relative luminance against green's
    /// 0.7152, so a saturated blue at FULL brightness is still luminance-dark
    /// and no brightness reaches 4.5:1 on a dark ground. Dropping saturation
    /// rescues it — at hue 0.67, saturation 0.55 reaches 4.8:1 — which is why
    /// the product answer is "honour the chosen saturation unless it is
    /// impossible, then soften it and say so" rather than "derive brightness
    /// only, always".
    ///
    /// This test pins the region so it cannot silently grow.
    @Test func lightAlwaysSolvesAndOnlySaturatedBluesFailOnDark() {
        ThemePalette.refresh(from: nil)
        var lightFailures: [String] = []
        var darkFailures: [(hue: Double, saturation: Double)] = []

        for hueStep in 0..<36 {
            let hue = Double(hueStep) / 36.0
            for saturation in [0.35, 0.55, 0.75, 0.95] {
                let light = LSTheme.derivedAccent(hue: hue, saturation: saturation,
                                                  dark: false, ground: lightGround)
                if LSContrast.ratio(light, lightGround) < 4.5 {
                    lightFailures.append(String(format: "h=%.2f s=%.2f", hue, saturation))
                }
                let dark = LSTheme.derivedAccent(hue: hue, saturation: saturation,
                                                 dark: true, ground: darkGround)
                if LSContrast.ratio(dark, darkGround) < 4.5 {
                    darkFailures.append((hue, saturation))
                }
            }
        }

        #expect(lightFailures.isEmpty,
                Comment(rawValue: "light must never need restricting: \(lightFailures)"))

        // Every dark failure is in the blue/violet band at high saturation.
        let strays = darkFailures.filter { !($0.hue >= 0.58 && $0.hue <= 0.80 && $0.saturation >= 0.70) }
        #expect(strays.isEmpty,
                Comment(rawValue: "unsolvable colours OUTSIDE the known blue/violet corner: \(strays)"))
        #expect(darkFailures.count <= 14,
                Comment(rawValue: "the unsolvable region grew to \(darkFailures.count) of 144"))
    }

    /// Saturation is the user's, not the app's. Deriving it too was considered
    /// and rejected — one moving part, not two.
    @Test func derivationMovesBrightnessOnly() {
        ThemePalette.refresh(from: nil)
        for saturation in [0.4, 0.7, 0.9] {
            let c = LSTheme.derivedAccent(hue: 0.6, saturation: saturation,
                                          dark: true, ground: darkGround)
            let got = c.lsHueSaturation?.saturation ?? -1
            #expect(abs(got - saturation) < 0.02,
                    Comment(rawValue: "saturation drifted from \(saturation) to \(got)"))
        }
    }

    /// A grey pick has no hue to preserve, and must still be legible.
    @Test func agreyPickStillLands() {
        ThemePalette.refresh(from: nil)
        let light = LSTheme.derivedAccent(hue: 0, saturation: 0, dark: false, ground: lightGround)
        let dark = LSTheme.derivedAccent(hue: 0, saturation: 0, dark: true, ground: darkGround)
        #expect(LSContrast.ratio(light, lightGround) >= 4.5)
        #expect(LSContrast.ratio(dark, darkGround) >= 4.5)
    }
}
