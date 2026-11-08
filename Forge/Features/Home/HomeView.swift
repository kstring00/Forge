import SwiftUI
import SwiftData
import ForgeCore

/// "Home · leveled up" (brief v4.2 §7): a grainy sky behind the date, the
/// settings button and "From idea to reality" with a live subline; the pipeline
/// as glowing nodes in the stage colours; the one next move with what's riding
/// on it; capture; then the ideas by stakes. The next move's idea never
/// appears twice.
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
    /// The idea the next-move card is about, kept out of the list below.
    private var moveIdeaID: UUID? {
        switch move {
        case .afterCapture(let id), .briefReady(let id), .unchecked(let id): id
        case .nextStep(let pid): activeProjects.first { $0.id == pid }?.idea?.id
        case .none: nil
        }
    }
    private func count(_ track: Track) -> Int { live.filter { $0.track == track }.count }
    private var byStakes: [Idea] {
        live.filter { $0.id != moveIdeaID }.sorted { a, b in
            let ma = EstimatedReturn.sortKey(for: a), mb = EstimatedReturn.sortKey(for: b)
            if (ma ?? -1) != (mb ?? -1) { return (ma ?? -1) > (mb ?? -1) }
            let ca = a.latestEvaluation?.confidence ?? -1, cb = b.latestEvaluation?.confidence ?? -1
            if ca != cb { return ca > cb }
            return a.updatedAt > b.updatedAt
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                        if live.isEmpty {
                            EmptyPanel()
                            QuickCaptureField(focusOnAppear: true)
                        } else {
                            PipelineStrip(counts: Track.allCases.map(count)) { env.tab = ForgeTab($0) }
                            nextMove
                            QuickCaptureField()
                            stakes
                        }
                    }
                    .padding(ForgeSpacing.m)
                    .padding(.bottom, ForgeSpacing.xxl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ForgeColor.canvas)
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .forgeDestinations()
        }
    }

    // MARK: Header

    private var inMotion: Int { count(.idea) + count(.formation) }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            SkyHeader()
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).replacingOccurrences(of: ", ", with: " · "))
                        .forgeLabel().foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.18), in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("From idea\nto reality")
                        .font(Font.custom("Fraunces-SemiBold", size: 40, relativeTo: .largeTitle))
                        .foregroundStyle(ForgeColor.ink)
                        .lineSpacing(-2)
                    if !live.isEmpty {
                        Text("\(inMotion) \(inMotion == 1 ? "idea" : "ideas") in motion · \(count(.reality)) out in the world")
                            .font(.system(size: 15)).foregroundStyle(ForgeColor.ink.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, ForgeSpacing.m)
            .padding(.top, 60)
            .padding(.bottom, ForgeSpacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                        Text("Hear the panel and rule on each voice.")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(ForgeColor.ink)
                        HStack(spacing: ForgeSpacing.s) {
                            IdeaSpark(idea: idea, size: 28)
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
                NextStepCard(project: project, style: .home, label: "Your next move", context: Track.reality.displayName)
            }
        case .unchecked(let id):
            if let idea = ideas.first(where: { $0.id == id }) { UncheckedCard(idea: idea) }
        case .none:
            EmptyView()
        }
    }

    // MARK: By stakes

    private var stakes: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your ideas, by stakes").font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Spacer()
                Button("All") { env.tab = .idea }
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(ForgeColor.emberText)
                    .accessibilityLabel("All ideas")
            }
            if byStakes.isEmpty {
                Text("Everything you have is in the card above.").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            ForEach(byStakes.prefix(8)) { idea in
                if let project = idea.project {
                    NavigationLink(value: WorkshopRoute.project(project.id)) {
                        StakeCard(idea: idea, checking: env.realityChecks.isRunning(idea.id))
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: VaultRoute.idea(idea.id)) {
                        StakeCard(idea: idea, checking: env.realityChecks.isRunning(idea.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, ForgeSpacing.s)
    }
}

/// The sky behind the header: lavender into violet, rose and ember, with the
/// grain, ending in the page's own colour so it melts into the ground in
/// either theme. A mesh where the OS has one; a soft linear fade before iOS 18.
struct SkyHeader: View {
    private let lavender = Color(hex: 0x8F82C8)
    private let violet = Color(hex: 0x7A5BB8)
    private let rose = Color(hex: 0xC97B86)
    private let ember = Color(hex: 0xD9772B)
    private let peach = Color(hex: 0xE8A77A)

    var body: some View {
        ZStack {
            if #available(iOS 18, *) {
                MeshGradient(width: 3, height: 4, points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.38], [0.55, 0.42], [1, 0.34],
                    [0, 0.72], [0.45, 0.78], [1, 0.70],
                    [0, 1], [0.5, 1], [1, 1],
                ], colors: [
                    lavender, violet, lavender,
                    rose, peach, violet.opacity(0.9),
                    ForgeColor.canvas.mixedToward(ember, 0.35), ForgeColor.canvas.mixedToward(peach, 0.45), ForgeColor.canvas.mixedToward(rose, 0.3),
                    ForgeColor.canvas, ForgeColor.canvas, ForgeColor.canvas,
                ])
            } else {
                LinearGradient(stops: [
                    .init(color: lavender, location: 0), .init(color: violet, location: 0.3),
                    .init(color: peach, location: 0.6), .init(color: ForgeColor.canvas, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            // Grain only where the sky still has colour.
            GrainGradient(colors: [.clear, .clear], grain: 0.22)
                .blendMode(.multiply)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
        }
        .accessibilityHidden(true)
    }
}

/// One idea by stakes: a stage-coloured side band, stage and verdict in mono,
/// the serif title, five mini orbs in their states, and the Est. return row
/// (or Impact). The title opens the idea; the row opens the estimate.
struct StakeCard: View {
    let idea: Idea
    var checking = false

    private var track: Track { idea.track ?? .idea }
    private var round: Round? { idea.rounds.max { $0.createdAt < $1.createdAt } }
    private var verdicts: [Verdict] { round?.verdicts ?? [] }
    private var tally: RoundTally { RoundTally(verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) }) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(Self.color(track)).frame(width: 3)
            IdeaSpark(idea: idea, size: 44).padding(.top, 14)
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let project = idea.project {
                        NavigationLink(value: WorkshopRoute.project(project.id)) { heading }
                    } else {
                        NavigationLink(value: VaultRoute.idea(idea.id)) { heading }
                    }
                }
                .buttonStyle(.plain)
                EstimatedReturnRow(idea: idea).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 14).padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(stageLine).forgeLabelSmall().foregroundStyle(Self.color(track))
                Spacer()
                if let right = rightLabel { Text(right).forgeLabelSmall().foregroundStyle(rightTint) }
                StageTrail(track: idea.track)
            }
            Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    static func color(_ t: Track) -> Color {
        switch t {
        case .idea: ForgeColor.lavender
        case .formation: Color(hex: 0x8B63C9)
        case .reality: ForgeColor.ember
        }
    }

    private var stageLine: String {
        var parts = [track.displayName]
        if checking { parts.append("Checking") }
        else if let project = idea.project, project.nextStep != nil {
            parts.append("\(min(project.nextStepCount, project.nextStepTarget)) of \(max(1, project.nextStepTarget))")
        } else if tally.total > 0 {
            parts.append(tally.isComplete ? "Ruled" : "Ruled \(tally.ruled) of \(tally.total)")
        } else if !RealityCheckPolicy.isOffered(for: idea.lensType) {
            parts.append("Judged by impact")
        } else {
            parts.append("Not checked")
        }
        return parts.joined(separator: " · ")
    }

    /// The verdict once there is one; the lens when the user chose one; else nothing.
    private var rightLabel: String? {
        if let v = idea.latestRealityCheck?.verdict { return v.displayName }
        return idea.lensType?.displayName
    }

    private var rightTint: Color {
        idea.latestRealityCheck != nil ? ForgeColor.emberText : ForgeColor.inkSecondary
    }
}

/// Idea (n) → Formation (n) → Reality (n): glowing 40 pt nodes in the stage
/// colours on a gradient line, each with a one-line status. Tap for the tab.
struct PipelineStrip: View {
    let counts: [Int]
    var onTap: (Track) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(Track.allCases.enumerated()), id: \.element) { i, track in
                    Button { onTap(track) } label: {
                        ZStack {
                            Circle().fill(StakeCard.color(track)).frame(width: 40, height: 40)
                                .shadow(color: StakeCard.color(track).opacity(0.55), radius: 10)
                            Text("\(counts[i])").font(ForgeType.numeralSmall).foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(track.displayName), \(counts[i]). \(status(track, counts[i]))")
                    if i < Track.allCases.count - 1 {
                        LinearGradient(colors: [StakeCard.color(track), StakeCard.color(Track.allCases[i + 1])], startPoint: .leading, endPoint: .trailing)
                            .frame(height: 2)
                    }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(Track.allCases.enumerated()), id: \.element) { i, track in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.displayName).forgeLabelSmall()
                        Text(status(track, counts[i])).font(.system(size: 12)).foregroundStyle(ForgeColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func status(_ t: Track, _ n: Int) -> String {
        if n == 0 { return "Nothing here yet" }
        switch t {
        case .idea: return "Waiting for the panel"
        case .formation: return "Waiting on your ruling"
        case .reality: return "Out in the world"
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
                    Spacer()
                    StopCheckButton(ideaID: idea.id)
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
                        Text(env.realityChecks.failure(for: idea.id) == nil ? Track.idea.displayName : "Last check didn't finish").forgeLabel()
                    }
                    Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                    OriginalText(text: idea.originalText).lineLimit(3)
                }
            }
            .buttonStyle(.plain)
            if env.realityChecks.isRunning(idea.id) {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("The panel is on it.").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    Spacer()
                    StopCheckButton(ideaID: idea.id)
                }
            } else {
                RealityCheckButton(idea: idea, compact: true)
            }
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
