import SwiftUI
import ForgeCore

/// Home usability pass, part (a): nothing on Home sits under the clock, the
/// Dynamic Island, the tab bar or the capture button. The sky still fills the
/// top at rest; once Home scrolls, a cover in the canvas colour builds over
/// the status bar, and rows fade out before they reach the capture button
/// and the tab bar. The sizes and the timing are `HomeEdges` in ForgeCore.

/// The canvas over the status bar, with a soft lower edge. `amount` runs from
/// 0 (the sky shows) to 1 (solid).
struct HomeTopCover: View {
    /// The height of the status bar or Dynamic Island area.
    let height: CGFloat
    let amount: Double

    var body: some View {
        VStack(spacing: 0) {
            ForgeColor.canvas.frame(height: max(0, height))
            LinearGradient(colors: [ForgeColor.canvas, ForgeColor.canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: HomeEdges.topFade)
        }
        .opacity(amount)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Rows fade into the canvas above the tab bar, and the canvas carries on
/// behind the bar, so no text shows through it or around the capture button.
/// It does not replace or restyle the bar: iOS draws that as it likes.
struct HomeBottomFade: View {
    /// The height of the tab bar area below the screen's safe area.
    let below: CGFloat

    static var fadeHeight: CGFloat {
        HomeEdges.bottomFade(button: CaptureDockButton.diameter, inset: CaptureDockButton.bottomInset)
    }

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(stops: HomeEdges.bottomFadeStops.map { .init(color: ForgeColor.canvas.opacity($0.opacity), location: $0.location) },
                           startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fadeHeight)
            ForgeColor.canvas.frame(height: max(0, below))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// On the scroll content: keeps `cover` at how solid the status-bar cover
    /// should be for how far the content has scrolled inside `space`. It moves
    /// in tenths, so Home redraws at most ten times on the way.
    func tracksHomeTopCover(_ cover: Binding<Double>, in space: String) -> some View {
        background(GeometryReader { g in
            let now = HomeEdges.topCover(scrolled: -g.frame(in: .named(space)).minY)
            Color.clear.onChange(of: now, initial: true) { _, value in cover.wrappedValue = value }
        })
    }

    /// Reads the safe area around this view (the status bar above, the tab bar below).
    func readsSafeArea(_ insets: Binding<EdgeInsets>) -> some View {
        background(GeometryReader { g in
            Color.clear.onChange(of: g.safeAreaInsets, initial: true) { _, value in insets.wrappedValue = value }
        })
    }
}

/// The key window's safe area: the status bar or Dynamic Island above, the
/// home indicator below. It knows nothing about the tab bar.
@MainActor
enum WindowInsets {
    static var current: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
}

#Preview("Home edges, scrolled") {
    ZStack(alignment: .bottomTrailing) {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<14, id: \.self) { i in
                Text("Idea \(i + 1): a title that runs all the way to the right-hand edge")
                    .font(.body).foregroundStyle(ForgeColor.ink)
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ForgeColor.canvas)
        .overlay(alignment: .top) { HomeTopCover(height: 59, amount: 1) }
        .overlay(alignment: .bottom) { HomeBottomFade(below: 0) }
        Circle().fill(ForgeColor.ember).frame(width: CaptureDockButton.diameter, height: CaptureDockButton.diameter)
            .padding(.trailing, ForgeSpacing.l).padding(.bottom, CaptureDockButton.bottomInset)
    }
    .preferredColorScheme(.dark)
}
