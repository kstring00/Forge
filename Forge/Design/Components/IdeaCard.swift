import SwiftUI
import ForgeCore

/// The Vault card (§7 v4.1 treatment). A thin sky band keyed to stage, a serif
/// title, the lens in mono caps, and the path implied on every card: six dim
/// Sphere dots and "Not yet checked", or the verdict word with a small
/// Confidence ring.
struct IdeaCard: View {
    let idea: Idea
    var status: IdeaStatus? = nil
    var compact = false

    private var resolved: IdeaStatus { status ?? IdeaStatus.of(idea) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(colors: ForgeColor.sky(for: idea.stage), startPoint: .leading, endPoint: .trailing)
                .frame(height: 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text(idea.title)
                    .font(ForgeType.ideaTitle)
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(compact ? 2 : 3)
                HStack(spacing: ForgeSpacing.m) {
                    Text(idea.lensType?.displayName ?? idea.stage.displayName).forgeLabel()
                    if idea.triage?.isComplete == true { Text("Screened").forgeLabel() }
                    Spacer()
                    Text(idea.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(ForgeColor.inkSecondary)
                }
                statusRow
            }
            .padding(ForgeSpacing.cardPadding)
        }
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch resolved {
        case .notChecked:
            HStack(spacing: ForgeSpacing.s) {
                SphereDots(lit: [])
                Text("Not yet checked").forgeLabel()
            }
        case .checking:
            HStack(spacing: ForgeSpacing.s) {
                SphereDots(lit: Set(Sphere.phase3Panel))
                Text("Checking").forgeLabel()
            }
        case .checked(let verdict, let confidence):
            HStack(spacing: ForgeSpacing.m) {
                Text(verdict.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
                Spacer()
                MiniRing(value: confidence, tint: ForgeColor.ember)
            }
        }
    }

    private var accessibilityText: String {
        var parts = [idea.title, idea.lensType?.displayName ?? idea.stage.displayName]
        switch resolved {
        case .notChecked: parts.append("not yet checked")
        case .checking: parts.append("checking")
        case .checked(let v, let c): parts.append("\(v.displayName), confidence \(c)")
        }
        return parts.joined(separator: ", ")
    }
}

/// Six dots in the Sphere colours, dim until lit.
struct SphereDots: View {
    var lit: Set<Sphere>
    private let order: [Sphere] = [.customer, .investor, .strategist, .builder, .skeptic, .steward]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(order) { s in
                Circle()
                    .fill(SphereOrb.palette(for: s).base)
                    .frame(width: 6, height: 6)
                    .opacity(lit.contains(s) ? 1 : 0.3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A 22pt Confidence ring for cards.
struct MiniRing: View {
    let value: Int
    var tint: Color = ForgeColor.ember

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(ForgeColor.line, lineWidth: 3)
                Circle().trim(from: 0, to: Double(min(max(value, 0), 100)) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            Text("\(value)").font(ForgeType.numeralTiny).foregroundStyle(ForgeColor.ink)
        }
        .accessibilityLabel("Confidence \(value)")
    }
}
