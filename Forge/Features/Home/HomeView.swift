import SwiftUI
import SwiftData
import ForgeCore

/// Brief v4.2 §7, the "Home overview" artboard: the mono date and the settings
/// button, no big title; the pipeline strip Idea → Formation → Reality; the
/// one next move; capture; then a short section per track, each with "All"
/// to its tab. The same idea never appears twice on the screen.
struct HomeView: View {
    let onCapture: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var activeProjects: [Project]

    private var live: [Idea] { ideas.filter { !$0.isArchived } }
    private var move: HomeCard {
        HomeCard.choose(justCaptured: env.justCapturedIdeaID, ideas: ideas, projects: activeProjects, unseenBriefs: env.realityChecks.unseenBriefs,
                        failedChecks: Set(env.realityChecks.failures.keys))
    }
    /// The idea the next-move card is about, kept out of the sections below.
    private var moveIdeaID: UUID? {
        switch move {
        case .afterCapture(let id), .briefReady(let id), .unchecked(let id): id
        case .nextStep(let pid): activeProjects.first { $0.id == pid }?.idea?.id
        case .none: nil
        }
    }
    private func onTrack(_ track: Track) -> [Idea] { live.filter { $0.stage.track == track } }
    private func section(_ track: Track) -> [Idea] { onTrack(track).filter { $0.id != moveIdeaID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    topRow
                    if live.isEmpty {
                        EmptyPanel()
                        QuickCaptureField(focusOnAppear: true)
                    } else {
                        Text("From idea to reality").font(ForgeType.ideaTitleHero).foregroundStyle(ForgeColor.ink)
                        PipelineStrip(counts: Track.allCases.map { onTrack($0).count }) { env.tab = ForgeTab($0) }
                        nextMove
                        QuickCaptureField()
                        trackSection(.idea)
                        trackSection(.formation)
                        trackSection(.reality)
                    }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ForgeColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .forgeDestinations()
        }
    }

    // MARK: Top row

    private var topRow: some View {
        HStack {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).replacingOccurrences(of: ", ", with: " · "))
                .forgeLabel()
            Spacer()
            NavigationLink { SettingsView() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
                    .frame(width: 36, height: 36)
                    .background(ForgeColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(ForgeColor.line))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, ForgeSpacing.s)
    }

    // MARK: The one next move

    @ViewBuilder
    private var nextMove: some View {
        switch move {
        case .afterCapture(let id):
            if let idea = ideas.first(where: { $0.id == id }) { AfterCaptureCard(idea: idea) }
        case .briefReady(let id):
            if let idea = ideas.first(where: { $0.id == id }), let check = idea.latestRealityCheck {
                NavigationLink(value: VaultRoute.idea(id)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Your next move").forgeLabel().foregroundStyle(ForgeColor.emberText)
                            Spacer()
                            Text(Track.formation.displayName).forgeLabel()
                        }
                        Text("Hear the panel on \(idea.title) and rule.")
                            .font(.system(size: 17, weight: .medium)).foregroundStyle(ForgeColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: ForgeSpacing.s) {
                            MiniPanel(verdicts: idea.rounds.max { $0.createdAt < $1.createdAt }?.verdicts ?? [])
                            Text(check.verdict.displayName).forgeLabelSmall().foregroundStyle(ForgeColor.emberText)
                        }
                        Text("Hear the panel")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(ForgeSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
                }
                .buttonStyle(.plain)
            }
        case .nextStep(let pid):
            if let project = activeProjects.first(where: { $0.id == pid }) {
                NextStepCard(project: project, label: "Your next move", context: Track.reality.displayName, compact: true)
            }
        case .unchecked(let id):
            if let idea = ideas.first(where: { $0.id == id }) { UncheckedCard(idea: idea) }
        case .none:
            EmptyView()
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func trackSection(_ track: Track) -> some View {
        let items = section(track)
        let total = onTrack(track).count
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(track.displayName).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Text("\(total)").font(ForgeType.numeralTiny).foregroundStyle(ForgeColor.inkSecondary)
                Spacer()
                Button("All") { env.tab = ForgeTab(track) }
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(ForgeColor.emberText)
                    .accessibilityLabel("All \(track.displayName)")
            }
            Text(track.tagline).font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
            if items.isEmpty {
                Text(total == 0 ? emptyLine(track) : "Nothing else here.").font(.caption).foregroundStyle(ForgeColor.inkSecondary).padding(.top, 2)
            }
            ForEach(items.prefix(3)) { idea in
                switch track {
                case .idea: IdeaRow(idea: idea)
                case .formation:
                    NavigationLink(value: VaultRoute.idea(idea.id)) {
                        FormationRow(idea: idea, checking: env.realityChecks.isRunning(idea.id))
                    }
                    .buttonStyle(.plain)
                case .reality:
                    if let project = idea.project {
                        NavigationLink(value: WorkshopRoute.project(project.id)) { RealityRow(project: project) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, ForgeSpacing.s)
    }

    private func emptyLine(_ track: Track) -> String {
        switch track {
        case .idea: "Every idea you catch starts here."
        case .formation: "Send an idea to the panel and it moves here."
        case .reality: "Say Looks right on a Brief and the first step lands here."
        }
    }
}

/// An unchecked idea on Home: the ember rule, the serif title, To the panel.
struct IdeaRow: View {
    let idea: Idea

    var body: some View {
        HStack(spacing: ForgeSpacing.m) {
            NavigationLink(value: VaultRoute.idea(idea.id)) {
                HStack(spacing: 12) {
                    Rectangle().fill(ForgeColor.lavender).frame(width: 2)
                    Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            if RealityCheckPolicy.isOffered(for: idea.lensType) {
                RealityCheckButton(idea: idea, pill: true)
            } else {
                Text("Judged by impact").forgeLabelSmall()
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}

/// A project on Home or the Reality tab: name, the step, how far, when due.
struct RealityRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.name).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(1)
                Spacer()
                Text(statusLabel).forgeLabelSmall()
            }
            if let step = project.nextStep {
                Text(step).font(.system(size: 15)).foregroundStyle(ForgeColor.ink).lineLimit(2)
                Text(progressLine).forgeLabelSmall()
            } else if project.status == .active {
                Text("No next step set.").font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

    private var statusLabel: String {
        switch project.status {
        case .active: "Active"
        case .paused: "Paused"
        case .done: "Launched"
        case .archived: "Archived"
        }
    }

    private var progressLine: String {
        var parts = ["\(min(project.nextStepCount, project.nextStepTarget)) of \(max(1, project.nextStepTarget))"]
        if let due = project.nextStepDueAt {
            parts.append((due < .now ? "was due " : "due ") + due.formatted(.dateTime.weekday(.abbreviated)))
        }
        return parts.joined(separator: " · ")
    }
}

/// Idea (n) → Formation (n) → Reality (n). Tap a stage for its tab.
struct PipelineStrip: View {
    let counts: [Int]
    var onTap: (Track) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(Track.allCases.enumerated()), id: \.element) { i, track in
                Button { onTap(track) } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(fill(track)).frame(width: 40, height: 40)
                            Circle().strokeBorder(stroke(track), lineWidth: track == .formation ? 1.5 : 1).frame(width: 40, height: 40)
                            Text("\(counts[i])").font(ForgeType.numeralSmall).foregroundStyle(track == .reality ? .white : ForgeColor.ink)
                        }
                        Text(track.displayName).forgeLabelSmall()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(track.displayName), \(counts[i])")
                if i < Track.allCases.count - 1 {
                    Rectangle().fill(ForgeColor.line).frame(height: 1).padding(.top, 20)
                }
            }
        }
    }

    private func fill(_ t: Track) -> Color {
        switch t {
        case .idea: ForgeColor.surface
        case .formation: ForgeColor.surface
        case .reality: ForgeColor.ember
        }
    }

    private func stroke(_ t: Track) -> Color {
        switch t {
        case .idea: ForgeColor.line
        case .formation: Color(hex: 0x8B63C9)
        case .reality: .clear
        }
    }
}

/// §7 after capture: Home turns toward the new idea. One tap to the panel.
struct AfterCaptureCard: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            Text("Your next move").forgeLabel().foregroundStyle(ForgeColor.emberText)
            Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
            if runner.isRunning {
                HStack(spacing: ForgeSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Working. The panel is on it; the idea sits in Formation when it's back.").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
            } else {
                Text(Spheres.afterCaptureLine).font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
                RealityCheckButton(idea: idea)
                HStack {
                    Spacer()
                    Button("Later") { env.justCapturedIdeaID = nil }
                        .font(.caption.weight(.medium)).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
        .onChange(of: runner.isRunning) { _, running in
            if running { env.justCapturedIdeaID = nil }
        }
    }
}

/// The most recent unchecked idea, with the Reality Check button on the card.
struct UncheckedCard: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            NavigationLink(value: VaultRoute.idea(idea.id)) {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    HStack {
                        Text("Your next move").forgeLabel().foregroundStyle(ForgeColor.emberText)
                        Spacer()
                        Text(env.realityChecks.failure(for: idea.id) == nil ? Track.idea.displayName : "Last check failed").forgeLabel()
                    }
                    Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                    OriginalText(text: idea.originalText).lineLimit(3)
                }
            }
            .buttonStyle(.plain)
            RealityCheckButton(idea: idea, compact: true)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}

/// §7 first launch: the orbs large and loose, one serif line, the capture field.
struct EmptyPanel: View {
    @State private var tapped: Sphere?
    private let offsets: [CGFloat] = [8, -10, 4, -6, 10, -2]

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.l) {
            HStack(spacing: 0) {
                ForEach(Array(Panel.order.enumerated()), id: \.element) { i, s in
                    Button {
                        withAnimation(ForgeMotion.settle) { tapped = tapped == s ? nil : s }
                    } label: {
                        OrbView(sphere: s, state: tapped == nil ? .idle : (tapped == s ? .speaking : .dim), size: 56)
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
