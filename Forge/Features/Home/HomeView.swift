import SwiftUI
import SwiftData
import ForgeCore

/// What am I thinking about? What am I working on? What should I do next?
/// No stats, no charts, ever.
struct HomeView: View {
    let onCapture: () -> Void

    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var activeProjects: [Project]
    @AppStorage("home.dismissedPromptDay") private var dismissedPromptDay: Int = 0

    private var recent: [Idea] { Array(ideas.filter { !$0.isArchived }.prefix(5)) }
    private var todayOrdinal: Int { Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    quickCapture
                    if let latest = recent.first {
                        section("Continue exploring") {
                            NavigationLink(value: VaultRoute.idea(latest.id)) {
                                IdeaCard(idea: latest)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let project = activeProjects.first {
                        section("Active workshop") {
                            NavigationLink(value: WorkshopRoute.project(project.id)) {
                                workshopCard(project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if recent.count > 1 {
                        section("Recently captured") {
                            ForEach(recent.dropFirst()) { idea in
                                NavigationLink(value: VaultRoute.idea(idea.id)) {
                                    IdeaCard(idea: idea)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if ideas.isEmpty {
                        EmptyState(symbol: "circle.lefthalf.filled",
                                   title: "A quiet studio",
                                   message: "Capture a thought and FORGE will keep it, untouched, until you are ready to look at it properly.")
                            .padding(.top, ForgeSpacing.xl)
                    }
                    if dismissedPromptDay != todayOrdinal {
                        reflectivePrompt
                    }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape").accessibilityLabel("Settings")
                    }
                }
            }
            .forgeDestinations()
        }
    }

    private var quickCapture: some View {
        Button(action: onCapture) {
            HStack {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    Text("Quick capture").forgeLabel()
                    Text("What's on your mind?")
                        .font(ForgeType.ideaTitle)
                        .foregroundStyle(ForgeColor.ink)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(ForgeColor.ember)
            }
            .padding(ForgeSpacing.cardPadding)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick capture")
    }

    private var reflectivePrompt: some View {
        HStack(alignment: .top, spacing: ForgeSpacing.m) {
            Text(ReflectivePrompts.prompt())
                .font(ForgeType.secondary)
                .foregroundStyle(ForgeColor.inkSecondary)
            Spacer()
            Button {
                dismissedPromptDay = todayOrdinal
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            .accessibilityLabel("Dismiss prompt")
        }
        .padding(ForgeSpacing.m)
    }

    private func workshopCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text(project.name)
                .font(ForgeType.ideaTitle)
                .foregroundStyle(ForgeColor.ink)
            Text("Next step").forgeLabel()
            Text(project.nextStep ?? "Not set yet.")
                .font(ForgeType.body)
                .foregroundStyle(project.nextStep == nil ? ForgeColor.inkSecondary : ForgeColor.ink)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text(title).forgeLabel()
            content()
        }
    }
}
