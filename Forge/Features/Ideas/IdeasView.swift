import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0025: every idea in one list, grouped under Idea / Formation /
/// Reality with each track's one-liner. Search, lens, tag and archived filters
/// stay. An empty section says how ideas get there. Home's pipeline nodes
/// land here scrolled to their section.
struct IdeasView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @State private var filter = VaultFilter()
    @State private var pendingArchive: Idea?

    private var shown: [Idea] { filter.apply(to: ideas) }
    private var grouped: [Track: [Idea]] { TrackCounts.grouped(shown) }
    private var tags: [String] { VaultFilter.allTags(in: ideas) }
    private var searching: Bool { !filter.searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if ideas.isEmpty {
                    EmptyState(symbol: "lightbulb",
                               title: "No ideas yet",
                               message: "Every idea you capture lands here, with its original wording kept exactly as you wrote it. The ember button is the way in.")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: ForgeSpacing.l) {
                                DailyQuote()
                                if filter.hasActiveFilter { activeFilters }
                                if filter.showArchived {
                                    archived
                                } else {
                                    ForEach(Track.allCases) { track in
                                        section(track, grouped[track] ?? []).id(track)
                                    }
                                }
                            }
                            .padding(ForgeSpacing.m)
                            .padding(.bottom, ForgeSpacing.dockClearance)
                        }
                        .onAppear { scrollIfAsked(proxy) }
                        .onChange(of: env.ideasSection) { _, _ in scrollIfAsked(proxy) }
                    }
                    .searchable(text: $filter.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search ideas")
                    .forgeAnimation(ForgeMotion.settle, value: shown.map(\.id))
                }
            }
            .captureDock()
            .background(ForgeColor.canvas)
            .navigationTitle(filter.showArchived ? "Archived" : ForgeTab.ideas.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .forgeDestinations()
            .confirmationDialog("Archive this idea?",
                                isPresented: Binding(get: { pendingArchive != nil }, set: { if !$0 { pendingArchive = nil } }),
                                titleVisibility: .visible) {
                Button("Archive") {
                    pendingArchive?.archive()
                    pendingArchive = nil
                }
                Button("Keep", role: .cancel) { pendingArchive = nil }
            } message: {
                Text("It moves out of Ideas but nothing is deleted. You can bring it back any time.")
            }
        }
    }

    private func scrollIfAsked(_ proxy: ScrollViewProxy) {
        guard let section = env.ideasSection else { return }
        env.ideasSection = nil
        DispatchQueue.main.async {
            withAnimation(ForgeMotion.settle) { proxy.scrollTo(section, anchor: .top) }
        }
    }

    // MARK: Sections

    private func section(_ track: Track, _ items: [Idea]) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: ForgeSpacing.s) {
                Circle().fill(StakeCard.color(track)).frame(width: 8, height: 8)
                Text(track.displayName).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Text("\(items.count)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.inkSecondary).monospacedDigit()
                Spacer()
            }
            Text(track.tagline).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
            if items.isEmpty {
                Text(searching || filter.hasActiveFilter ? "Nothing here matches." : track.howIdeasArrive)
                    .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                    .padding(ForgeSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ForgeColor.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            }
            ForEach(items) { idea in row(idea) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(track.displayName), \(items.count). \(track.tagline)")
    }

    /// The card's header opens the idea (or its step); its one primary action sits under it.
    private func row(_ idea: Idea) -> some View {
        IdeaCard(idea: idea, status: IdeaStatus.of(idea, checking: env.realityChecks.isRunning(idea.id), failed: env.realityChecks.failure(for: idea.id) != nil))
            .contextMenu { contextMenu(for: idea) }
    }

    @ViewBuilder
    private var archived: some View {
        if shown.isEmpty {
            EmptyState(symbol: "archivebox", title: "Nothing archived", message: "Archived ideas will show here. They are history, not failure.")
                .padding(.top, ForgeSpacing.xl)
        } else {
            Text("\(shown.count) archived").forgeLabel()
            ForEach(shown) { idea in
                IdeaCard(idea: idea, showsAction: false)
                    .contextMenu { contextMenu(for: idea) }
            }
        }
    }

    // MARK: Filter UI

    private var filterMenu: some View {
        Menu {
            Picker("Sort", selection: $filter.sort) {
                ForEach(VaultSort.allCases) { sort in
                    Text(sort.displayName).tag(sort)
                }
            }
            .pickerStyle(.menu)
            if filter.sort.requiresLens && filter.lens == nil {
                Text("Pick a kind of idea to sort by score")
            }
            Divider()
            Menu("Kind of idea (lens)") {
                Button("Any kind") { filter.lens = nil }
                ForEach(LensType.allCases) { lens in
                    Button {
                        filter.lens = lens
                    } label: {
                        if filter.lens == lens { Label(lens.displayName, systemImage: "checkmark") } else { Text(lens.displayName) }
                    }
                }
            }
            if !tags.isEmpty {
                Menu("Tag") {
                    Button("Any tag") { filter.tag = nil }
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            filter.tag = tag
                        } label: {
                            if filter.tag == tag { Label(tag, systemImage: "checkmark") } else { Text(tag) }
                        }
                    }
                }
            }
            Divider()
            Toggle("Show archived", isOn: $filter.showArchived)
        } label: {
            Image(systemName: filter.hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Sort and filter")
        }
    }

    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ForgeSpacing.s) {
                if let lens = filter.lens { chip(lens.displayName) { filter.lens = nil } }
                if let tag = filter.tag { chip("#\(tag)") { filter.tag = nil } }
                if filter.showArchived { chip("Archived") { filter.showArchived = false } }
            }
        }
    }

    private func chip(_ text: String, clear: @escaping () -> Void) -> some View {
        Button(action: clear) {
            HStack(spacing: ForgeSpacing.xs) {
                Text(text).font(.footnote.weight(.medium))
                Image(systemName: "xmark").font(.footnote)
            }
            .padding(.horizontal, ForgeSpacing.m)
            .padding(.vertical, ForgeSpacing.s)
            .foregroundStyle(ForgeColor.ink)
            .background(ForgeColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(text)")
    }

    @ViewBuilder
    private func contextMenu(for idea: Idea) -> some View {
        if idea.isArchived {
            Button { idea.unarchive() } label: { Label("Bring back", systemImage: "arrow.uturn.backward") }
        } else {
            Button { pendingArchive = idea } label: { Label("Archive", systemImage: "archivebox") }
        }
    }
}
