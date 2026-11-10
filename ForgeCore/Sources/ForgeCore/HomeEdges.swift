import Foundation

/// Home usability pass, part (a): nothing on Home sits under the clock, the
/// Dynamic Island, the tab bar or the capture button. The numbers live here
/// so they are tested; the views only draw them.
public enum HomeEdges {
    /// How far Home scrolls before the cover over the status bar is solid.
    public static let coverDistance: Double = 40
    /// The soft edge under that cover.
    public static let topFade: Double = 14
    /// Space kept between the end of the list and where the bottom fade starts.
    public static let listGap: Double = 8

    /// How solid the cover over the status bar is, from 0 (at the top: the sky
    /// shows through) to 1 (scrolled: rows pass behind it, not under the clock).
    /// In tenths, so scrolling changes it at most ten times and never redraws
    /// Home on every frame.
    public static func topCover(scrolled: Double, over distance: Double = coverDistance) -> Double {
        guard distance > 0, scrolled.isFinite else { return scrolled > 0 ? 1 : 0 }
        let t = min(1, max(0, scrolled / distance))
        return (t * 10).rounded() / 10
    }

    /// Where the header's first line starts: where the design puts it, or just
    /// below the status bar or Dynamic Island when that reaches further down.
    public static func headerTop(safeAreaTop: Double, design: Double = 60, gap: Double = 6) -> Double {
        max(design, max(0, safeAreaTop) + gap)
    }

    /// The height of the fade above the tab bar: the capture button, the space
    /// under it, and room above it for the fade to build. Rows are almost gone
    /// by the time they reach the button.
    public static func bottomFade(button: Double, inset: Double, lead: Double = 24) -> Double {
        max(0, button) + max(0, inset) + max(0, lead)
    }

    /// The space after the last row, so it stops clear of the fade, the
    /// capture button and the tab bar.
    public static func listBottomPadding(button: Double, inset: Double) -> Double {
        bottomFade(button: button, inset: inset) + listGap
    }

    /// The fade's stops, top to bottom: (how solid, how far down), both 0 to 1.
    /// With the default button the button's top edge sits about a quarter of
    /// the way down, where the fade is already half solid.
    public static let bottomFadeStops: [(opacity: Double, location: Double)] = [
        (0, 0), (0.55, 0.28), (0.92, 0.6), (1, 1),
    ]
}
