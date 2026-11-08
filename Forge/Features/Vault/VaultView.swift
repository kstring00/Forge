import SwiftUI
import SwiftData
import ForgeCore

/// The Idea tab: the Vault. Captured ideas not yet checked, as cards; every
/// track with one toggle. Search, filter by lens and tag, sort, archive.
struct VaultView: View {
    var onCapture: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @State private var lastOffset: CGFloat = 0
    /// The capture button hides while the list moves, and comes back once it rests or nears the top.
    @State private var fabHidden = false
    @State private var restTask: Task<Void, Never>?
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @State private var filter = VaultFilter()
    @State private var allTracks = false
    @State private var pendingArchive: Idea?

    private var base: [Idea] { allTracks ? ideas : ideas.filter { $0.isArchived || $0.stage.track == .idea } }
    private var shown: [Idea] { filter.apply(to: base) }
    private var tags: [String] { VaultFilter.allTags(in: ideas) }

    var body: some View {
        NavigationStack {
            Group {
                if ideas.isEmpty {
                    EmptyState(symbol: "archivebox",
                               title: "No ideas yet",
                               message: "Every idea you capture lands here, with its original wording kept exactly as you wrote it.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.m) {
                            if filter.hasActiveFilter || allTracks { activeFilters }
                            if shown.isEmpty {
                                EmptyState(symbol: "magnifyingglass",
                                           title: filter.showArchived ? "Nothing archived" : (filter.hasActiveFilter || !filter.searchText.isEmpty ? "No matches" : "Nothing waiting"),
                                           message: filter.showArchived
                                                ? "Archived ideas will show here. They are history, not failure."
                                                : (filter.hasActiveFilter || !filter.searchText.isEmpty ? "Try fewer words, or clear a filter." : "Every idea here has gone to the panel. Catch another, or show every track from the filter menu."))
                                    .padding(.top, ForgeSpacing.xl)
                            } else {
                                Text("\(shown.count) \(shown.count == 1 ? "idea" : "ideas")\(allTracks ? " · every track" : "")").forgeLabel()
                                ForEach(shown) { idea in
                                    NavigationLink(value: VaultRoute.idea(idea.id)) {
                                        IdeaCard(idea: idea, status: IdeaStatus.of(idea, checking: env.realityChecks.isRunning(idea.id), failed: env.realityChecks.failure(for: idea.id) != nil))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { contextMenu(for: idea) }
                                }
                            }
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.xxl * 2)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("vaultScroll")).minY)
                        })
                    }
                    .coordinateSpace(name: "vaultScroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        scrolled(to: offset)
                    }
                    .searchable(text: $filter.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search ideas")
                    .forgeAnimation(ForgeMotion.settle, value: shown.map(\.id))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !fabHidden {
                    EmberButton.floating(title: "Capture", symbol: "plus", action: onCapture)
                        .padding(.trailing, ForgeSpacing.l)
                        .padding(.bottom, ForgeSpacing.l)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .forgeAnimation(ForgeMotion.fade, value: fabHidden)
            .background(ForgeColor.canvas)
            .navigationTitle(filter.showArchived ? "Archived" : Track.idea.displayName)
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
                Text("It moves out of the Vault but nothing is deleted. You can bring it back any time.")
            }
        }
    }

    /// Any movement hides the button so it never sits over a card while the
    /// user reads; it returns near the top, or after the list has rested.
    private func scrolled(to offset: CGFloat) {
        defer { lastOffset = offset }
        guard abs(offset - lastOffset) > 2 else { return }
        if offset > -24 {
            fabHidden = false
            restTask?.cancel()
            return
        }
        fabHidden = true
        restTask?.cancel()
        restTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if !Task.isCancelled { fabHidden = false }
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
                Text("Pick a lens to sort by score")
            }
            Divider()
            Menu("Lens") {
                Button("Any lens") { filter.lens = nil }
                ForEach(LensType.allCases) { lens in
                    Button {
                        filter.lens = lens
                    } label: {
                        if filter.lens == lens { Label(lens.displayName, systemImage: "checkmark") } else { Text(lens.displayName) }
                    }
                }
            }
            Toggle("Every track", isOn: $allTracks)
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
                if allTracks { chip("Every track") { allTracks = false } }
                if let tag = filter.tag { chip("#\(tag)") { filter.tag = nil } }
                if filter.showArchived { chip("Archived") { filter.showArchived = false } }
            }
        }
    }

    private func chip(_ text: String, clear: @escaping () -> Void) -> some View {
        Button(action: clear) {
            HStack(spacing: ForgeSpacing.xs) {
                Text(text).font(.caption.weight(.medium))
                Image(systemName: "xmark").font(.caption2)
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

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
