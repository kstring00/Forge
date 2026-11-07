import SwiftUI
import SwiftData
import ForgeCore

/// §7: the orbs, permanent at the top of Home, reflecting the most recent
/// idea. Idle, working with a line per Sphere as it starts, or holding a verdict.
struct PanelHeader: View {
    let ideas: [Idea]
    @Environment(AppEnvironment.self) private var env
    @State private var tapped: Sphere?

    private let order: [Sphere] = [.customer, .investor, .strategist, .builder, .skeptic, .steward]
    private var center: RealityCheckCenter { env.realityChecks }

    private var focus: (idea: Idea, runner: RealityCheckRunner)? {
        if let run = center.activeRun, let idea = ideas.first(where: { $0.id == run.ideaID }) { return (idea, run.runner) }
        if let id = center.focusIdeaID, let idea = ideas.first(where: { $0.id == id }) { return (idea, center.runner(for: id)) }
        return nil
    }

    private var held: Idea? {
        if let f = focus, f.idea.latestRealityCheck != nil, !f.runner.isRunning { return f.idea }
        return ideas.filter { !$0.isArchived && $0.latestRealityCheck != nil }
            .max { ($0.latestRealityCheck?.createdAt ?? .distantPast) < ($1.latestRealityCheck?.createdAt ?? .distantPast) }
    }

    var body: some View {
        let phase = focus?.runner.phase ?? .idle
        let lit = focus?.runner.litSpheres ?? []
        let working = RealityCheckCenter.working(for: phase, lit: lit)
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(spacing: 0) {
                ForEach(order) { s in
                    Button {
                        withAnimation(ForgeMotion.settle) { tapped = tapped == s ? nil : s }
                    } label: {
                        OrbView(sphere: s, state: orbState(s, working: working), size: 48)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(s.displayName)
                }
            }

            if let tapped {
                Text(Spheres.profile(for: tapped).oneLine)
                    .font(ForgeType.statement)
                    .foregroundStyle(ForgeColor.ink)
                    .transition(.opacity)
            } else if let f = focus, f.runner.isRunning {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    ForEach(RealityCheckCenter.narration(for: phase, lit: lit), id: \.0) { sphere, line in
                        HStack(spacing: ForgeSpacing.s) {
                            Circle().fill(OrbView.palette(for: sphere).base).frame(width: 6, height: 6)
                            Text("\(sphere.displayName) · \(line)").font(.system(size: 13)).foregroundStyle(ForgeColor.ink)
                        }
                    }
                    Text(f.idea.title).font(.caption).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
                }
                .transition(.opacity)
            } else if let f = focus, f.idea.latestRealityCheck == nil, center.failure(for: f.idea.id) != nil {
                NavigationLink(value: VaultRoute.idea(f.idea.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The check didn't finish").font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
                        Text("\(f.idea.title) · open to see why").font(.caption).foregroundStyle(ForgeColor.emberText).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            } else if let held, let check = held.latestRealityCheck {
                NavigationLink(value: VaultRoute.idea(held.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.verdict.displayName).font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
                        Text(held.title).font(.caption).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func orbState(_ s: Sphere, working: Set<Sphere>) -> OrbState {
        if s == .steward { return .dormant }
        if working.contains(s) { return .working }
        if let tapped { return tapped == s ? .speaking : .dim }
        return .idle
    }
}

/// §7 first launch: the orbs large and loose, one serif line, the capture field.
struct EmptyPanel: View {
    @State private var tapped: Sphere?
    private let order: [Sphere] = [.customer, .investor, .strategist, .builder, .skeptic, .steward]
    private let offsets: [CGFloat] = [8, -10, 4, -6, 10, -2]

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.l) {
            HStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element) { i, s in
                    Button {
                        withAnimation(ForgeMotion.settle) { tapped = tapped == s ? nil : s }
                    } label: {
                        OrbView(sphere: s, state: tapped == nil ? .idle : (tapped == s ? .speaking : .dim), size: 64)
                            .offset(y: offsets[i])
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(s.displayName)
                    .accessibilityHint(Spheres.profile(for: s).oneLine)
                }
            }
            .padding(.vertical, ForgeSpacing.m)
            Text(tapped.map { Spheres.profile(for: $0).oneLine } ?? Spheres.emptyHomeLine)
                .font(ForgeType.statement)
                .foregroundStyle(ForgeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .animation(ForgeMotion.fade, value: tapped)
        }
    }
}
