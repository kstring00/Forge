import SwiftUI
import SwiftData
import ForgeCore

/// Home (decision 0044, the usability pass): what to do next in one glance,
/// and how every idea is doing in one scroll. A short sky header with the
/// checks pill and settings; the three stages, which filter the list; one
/// "Your next move" card with the only filled orange button; then the ideas
/// as compact rows that open in place. Capture is the mic button.
@MainActor
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var activeProjects: [Project]
    /// Home pass (a): the status bar above and the tab bar below, and how solid the cover over the status bar is.
    @State private var safeArea = EdgeInsets()
    @State private var topCover: Double = 0
    private static let scrollSpace = "home.scroll"
    /// The window's own insets are the floor, in case the reading above comes back empty.
    private var topInset: CGFloat { max(safeArea.top, WindowInsets.current.top) }
    private var bottomInset: CGFloat { max(safeArea.bottom, WindowInsets.current.bottom) }
    /// Home pass (b): the stage the list is filtered to, and the row opened or closed by hand.
    @State private var stageFilter: Track?
    @AppStorage("home.openRow") private var openRowRaw = ""

    private var live: [Idea] { TrackCounts.live(ideas) }
    private var move: HomeCard {
        HomeCard.choose(justCaptured: env.justCapturedIdeaID, ideas: ideas, projects: activeProjects, unseenBriefs: env.realityChecks.unseenBriefs,
                        failedChecks: Set(env.realityChecks.failures.keys))
    }
    /// The idea the next-move card is about. It is also the first row, tagged "Next".
    private var moveIdeaID: UUID? {
        switch move {
        case .afterCapture(let id), .briefReady(let id), .unchecked(let id): id
        case .nextStep(let pid): activeProjects.first { $0.id == pid }?.idea?.id
        case .none: nil
        }
    }

    private func state(_ idea: Idea) -> HomeRowState {
        HomeRowState.of(idea, checking: env.realityChecks.isRunning(idea.id), failed: env.realityChecks.failure(for: idea.id) != nil,
                        offline: env.realityChecks.isOffline(idea.id), unseenBrief: env.realityChecks.unseenBriefs.contains(idea.id))
    }
    /// Every live idea as its row needs it (decision 0025: the same ideas the stage counts count).
    private var rowIdeas: [HomeRowIdea] {
        live.compactMap { idea in idea.track.map { HomeRowIdea(id: idea.id, track: $0, workedAt: idea.updatedAt, state: state(idea)) } }
    }

    var body: some View {
        let rows = rowIdeas
        let list = HomeRows.list(rows, nextMoveID: moveIdeaID, stage: stageFilter)
        let open = HomeRows.openRow(rows, nextMoveID: moveIdeaID, memory: HomeOpenRowMemory(raw: openRowRaw))
        return NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                            if live.isEmpty {
                                HomeEmptyState()
                            } else {
                                PipelineStrip(counts: TrackCounts.counts(ideas), selected: stageFilter) { tapped in
                                    withAnimation(reduceMotion ? ForgeMotion.fade : ForgeMotion.settle) {
                                        stageFilter = HomeRows.toggled(stageFilter, tapped: tapped)
                                    }
                                }
                                nextMove
                                ideaRows(list, open: open, all: rows, proxy: proxy)
                            }
                        }
                        .padding(ForgeSpacing.m)
                        // The last row stops clear of the fade, the capture button and the tab bar.
                        .padding(.bottom, HomeEdges.listBottomPadding(button: CaptureDockButton.diameter, inset: CaptureDockButton.bottomInset))
                    }
                    .tracksHomeTopCover($topCover, in: Self.scrollSpace)
                }
                .coordinateSpace(.named(Self.scrollSpace))
            }
            .background(ForgeColor.canvas)
            .ignoresSafeArea(edges: .top)
            // Read outside the line above: inside it, the top inset reads as zero.
            .readsSafeArea($safeArea)
            // The sky fills the top at rest; once Home scrolls, rows pass behind the canvas, not under the clock.
            .overlay(alignment: .top) { HomeTopCover(height: topInset, amount: topCover) }
            // Rows fade out above the tab bar and the capture button; the canvas carries on behind the bar.
            .overlay(alignment: .bottom) { HomeBottomFade(below: bottomInset).offset(y: bottomInset) }
            .toolbar(.hidden, for: .navigationBar)
            .captureDock()
            .forgeDestinations()
            // A light tap when a row opens or closes.
            .sensoryFeedback(.selection, trigger: open)
        }
    }

    // MARK: Header

    /// Shorter than before: the date and settings, the name, the checks pill.
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            SkyHeader()
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.system(.footnote, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                    Spacer()
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.18), in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }
                Text("Have a hunch?")
                    .font(Font.custom("Fraunces-SemiBold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(ForgeColor.ink)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
                // Decision 0032: the checks pill, always on Home.
                ChecksPill()
                BillingIssueBanner()
            }
            .padding(.horizontal, ForgeSpacing.m)
            // Below the status bar or Dynamic Island on every phone.
            .padding(.top, HomeEdges.headerTop(safeAreaTop: topInset))
            .padding(.bottom, ForgeSpacing.m)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The one next move

    @ViewBuilder
    private var nextMove: some View {
        if let id = moveIdeaID, let idea = ideas.first(where: { $0.id == id }) {
            let s = state(idea)
            HomeNextMoveCard(idea: idea, state: s, move: HomeNextMoveCard.moveLine(for: idea, state: s), justCaptured: env.justCapturedIdeaID == id)
        } else if case .nextStep(let pid) = move, let project = activeProjects.first(where: { $0.id == pid }) {
            // A step with no idea behind it (older data): the step's own card.
            NextStepCard(project: project, style: .home, label: "Your next move", context: Track.reality.displayName)
        }
    }

    // MARK: Your ideas

    private func ideaRows(_ list: HomeRows.List, open: UUID?, all: [HomeRowIdea], proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(stageFilter.map { "Your ideas in \($0.displayName)" } ?? "Your ideas")
                    .font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if stageFilter != nil {
                    Button("Show all") {
                        withAnimation(reduceMotion ? ForgeMotion.fade : ForgeMotion.settle) { stageFilter = nil }
                    }
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.ink)
                    .frame(minHeight: 44)
                }
            }
            if list.rows.isEmpty, let stage = stageFilter {
                Text("Nothing in \(stage.displayName) yet. \(Self.emptyStageLine(stage))")
                    .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(list.rows) { row in
                if let idea = ideas.first(where: { $0.id == row.id }) {
                    HomeIdeaRow(idea: idea, state: row.state, isNext: row.id == moveIdeaID, isOpen: row.id == open) {
                        let opening = open != row.id
                        // A short spring; a plain fade with Reduce Motion.
                        withAnimation(reduceMotion ? ForgeMotion.fade : .spring(response: 0.32, dampingFraction: 0.86)) {
                            openRowRaw = HomeRows.afterTap(row.id, open: open, ideas: all).raw
                            if opening { proxy.scrollTo(Self.anchor(row.id)) }
                        }
                    }
                    // A point just above the row, below the status bar: scrolling to it brings the title into view.
                    .background(alignment: .top) {
                        Color.clear.frame(height: 1)
                            .alignmentGuide(.top) { d in d[.top] + topInset + ForgeSpacing.m }
                            .id(Self.anchor(row.id))
                    }
                }
            }
            if list.hasMore {
                Button { env.showIdeas(stageFilter) } label: {
                    HStack(spacing: 4) {
                        Text(stageFilter.map { "See all \(list.total) in \($0.displayName)" } ?? "See all \(list.total) ideas")
                            .font(.system(.subheadline, weight: .medium))
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(ForgeColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ForgeColor.line))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func anchor(_ id: UUID) -> String { "home.row.\(id.uuidString)" }

    private static func emptyStageLine(_ stage: Track) -> String {
        switch stage {
        case .idea: "New ideas land here until the panel has looked at them."
        case .formation: "An idea moves here once the panel has given its take."
        case .reality: "An idea moves here when you take a first step with real people."
        }
    }
}

/// The sky behind the header: lavender into violet, rose and ember, with the
/// grain, ending in the page's own colour so it melts into the ground in
/// either theme. A mesh where the OS has one; a soft linear fade before iOS 18.
struct SkyHeader: View {
    private let lavender = Color(hex: 0x8F82C8)
    private let violet = Color(hex: 0x7A5BB8)
    private let indigo = Color(hex: 0x3B2E6E)
    private let deepViolet = Color(hex: 0x4C3A86)
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
                    indigo, deepViolet, indigo,
                    violet.mixedToward(rose, 0.5), peach.mixedToward(rose, 0.35), violet,
                    ForgeColor.canvas.mixedToward(ember, 0.35), ForgeColor.canvas.mixedToward(peach, 0.45), ForgeColor.canvas.mixedToward(rose, 0.3),
                    ForgeColor.canvas, ForgeColor.canvas, ForgeColor.canvas,
                ])
            } else {
                LinearGradient(stops: [
                    .init(color: indigo, location: 0), .init(color: violet, location: 0.3),
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
                // Decision 0025: the verdict word on its own line, the figure beneath it, never more than two lines.
                VStack(alignment: .leading, spacing: 6) {
                    PanelAndProof(idea: idea)
                    EstimatedReturnRow(idea: idea)
                }
                // Decision 0036: one primary action, full width, at the bottom of the card.
                CardPrimaryAction(idea: idea).padding(.top, 4)
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
                Text(stageLine).forgeLabelSmall().foregroundStyle(Self.color(track)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                StageTrail(track: idea.track)
            }
            Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            IdeaSubtitle(idea: idea)
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
        else if track == .reality && idea.latestRealityCheck == nil { parts.append("No panel yet") }
        else if let project = idea.project, project.nextStep != nil {
            parts.append("\(min(project.nextStepCount, project.effectiveTarget)) of \(project.effectiveTarget)")
        } else if tally.total > 0 {
            parts.append(tally.isComplete ? "Ruled" : "Ruled \(tally.ruled) of \(tally.total)")
        } else if !RealityCheckPolicy.isOffered(for: idea.lensType) {
            parts.append("Judged by impact")
        } else {
            parts.append("Not checked")
        }
        return parts.joined(separator: " · ")
    }

}

/// Idea (n) → Formation (n) → Reality (n): glowing 40 pt nodes in the stage
/// colours on a gradient line, each with a one-line status. Tapping a stage
/// filters Home's list to it; tapping it again clears the filter. The chosen
/// stage gets a ring and a tick, not only its colour.
struct PipelineStrip: View {
    let counts: [Int]
    var selected: Track? = nil
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
                            if selected == track {
                                Circle().strokeBorder(ForgeColor.ink, lineWidth: 2).frame(width: 48, height: 48)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(track.displayName), \(counts[i]). \(status(track, counts[i]))")
                    .accessibilityHint(selected == track ? "Showing only these. Tap to show all ideas." : "Shows only these ideas.")
                    .accessibilityAddTraits(selected == track ? .isSelected : [])
                    if i < Track.allCases.count - 1 {
                        LinearGradient(colors: [StakeCard.color(track), StakeCard.color(Track.allCases[i + 1])], startPoint: .leading, endPoint: .trailing)
                            .frame(height: 2)
                    }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(Track.allCases.enumerated()), id: \.element) { i, track in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            if selected == track {
                                Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(ForgeColor.ink)
                            }
                            Text(track.displayName).font(.system(.footnote, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                        }
                        Text(selected == track ? "Showing these" : status(track, counts[i]))
                            .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func status(_ t: Track, _ n: Int) -> String {
        if n == 0 { return "Nothing here yet" }
        switch t {
        case .idea: return "Waiting for the panel"
        case .formation: return "Waiting on your decision"
        case .reality: return "Out in the world"
        }
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
