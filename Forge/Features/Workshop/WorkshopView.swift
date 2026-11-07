import SwiftUI
import SwiftData

/// Where a chosen idea becomes a project. Phase 0: empty state only.
struct WorkshopView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    EmptyState(symbol: "hammer",
                               title: "No project yet",
                               message: "When an idea has earned it, convert it here and the Workshop will always tell you the one next step.")
                } else {
                    List(projects) { project in
                        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                            Text(project.name).font(ForgeType.ideaTitle)
                            Text(project.status.rawValue).forgeLabel()
                        }
                        .listRowBackground(ForgeColor.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Workshop")
        }
    }
}
