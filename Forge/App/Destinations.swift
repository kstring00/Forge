import SwiftUI
import SwiftData

/// Shared navigation destinations so every tab's stack can open an idea or a project.
extension View {
    func forgeDestinations() -> some View {
        self
            .navigationDestination(for: VaultRoute.self) { route in
                switch route {
                case .idea(let id): IdeaDestination(id: id)
                }
            }
            .navigationDestination(for: WorkshopRoute.self) { route in
                switch route {
                case .project(let id): ProjectDestination(id: id)
                }
            }
    }
}

struct IdeaDestination: View {
    @Query private var ideas: [Idea]

    init(id: UUID) {
        _ideas = Query(filter: #Predicate<Idea> { $0.id == id })
    }

    var body: some View {
        if let idea = ideas.first {
            IdeaDetailView(idea: idea)
        } else {
            EmptyState(symbol: "questionmark", title: "Idea not found", message: "It may have been removed.")
                .background(ForgeColor.canvas)
        }
    }
}

struct ProjectDestination: View {
    @Query private var projects: [Project]

    init(id: UUID) {
        _projects = Query(filter: #Predicate<Project> { $0.id == id })
    }

    var body: some View {
        if let project = projects.first {
            ProjectDetailView(project: project)
        } else {
            EmptyState(symbol: "questionmark", title: "Project not found", message: "It may have been removed.")
                .background(ForgeColor.canvas)
        }
    }
}
