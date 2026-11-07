import SwiftUI
import SwiftData
import ForgeCore

/// Every idea, as cards. Search, filter by lens, stage and tag, sort, archive.
struct VaultView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @State private var filter = VaultFilter()
    @State private var pendingArchive: Idea?

    private var shown: [Idea] { filter.apply(to: ideas) }
    private var tags: [String] { VaultFilter.allTags(in: ideas) }

    var body: some View {
        NavigationStack {
            Group {
                if ideas.isEmpty {
                    EmptyState(symbol: "archivebox",
                               title: "Nothing in the Vault yet",
                               message: "Every idea you capture lands here, with its original wording kept exactly as you wrote it.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.m) {
                            if filter.hasActiveFilter { activeFilters }
                            if shown.isEmpty {
                                EmptyState(symbol: "magnifyingglass",
                                           title: filter.showArchived ? "Nothing archived" : "No matches",
                                           message: filter.showArchived
                                                ? "Archived ideas will show here. They are history, not failure."
                                                : "Try fewer words, or clear a filter.")
                                    .padding(.top, ForgeSpacing.xl)
                            } else {
                                Text("\(shown.count) \(shown.count == 1 ? "idea" : "ideas")").forgeLabel()
                                ForEach(shown) { idea in
                                    NavigationLink(value: VaultRoute.idea(idea.id)) {
                                        IdeaCard(idea: idea)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { contextMenu(for: idea) }
                                }
                            }
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.xxl * 2)
                    }
                    .searchable(text: $filter.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search ideas")
                    .forgeAnimation(ForgeMotion.settle, value: shown.map(\.id))
                }
            }
            .background(ForgeColor.canvas)
            .navigationTitle(filter.showArchived ? "Archived" : "Vault")
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
            Menu("Stage") {
                Button("Any stage") { filter.stage = nil }
                ForEach(Stage.allCases.filter { $0 != .archived }, id: \.self) { stage in
                    Button {
                        filter.stage = stage
                    } label: {
                        if filter.stage == stage { Label(stage.displayName, systemImage: "checkmark") } else { Text(stage.displayName) }
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
                if let stage = filter.stage { chip(stage.displayName) { filter.stage = nil } }
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
