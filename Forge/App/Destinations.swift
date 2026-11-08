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
                case .journal: JournalView()
                }
            }
            .navigationDestination(for: LabRoute.self) { route in
                switch route {
                case .criterion(let evaluationID, let key): CriterionDestination(evaluationID: evaluationID, key: key)
                case .history(let ideaID): HistoryDestination(ideaID: ideaID)
                case .round(let roundID): RoundDestination(roundID: roundID)
                case .criteria(let ideaID): CriteriaDestination(ideaID: ideaID)
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

struct CriterionDestination: View {
    @Query private var evaluations: [Evaluation]
    let key: String

    init(evaluationID: UUID, key: String) {
        self.key = key
        _evaluations = Query(filter: #Predicate<Evaluation> { $0.id == evaluationID })
    }

    var body: some View {
        if let evaluation = evaluations.first, let criterion = evaluation.lens.criterion(key) {
            CriterionDetailView(evaluation: evaluation, criterion: criterion)
        } else {
            EmptyState(symbol: "questionmark", title: "Criterion not found", message: "It may have been removed.")
                .background(ForgeColor.canvas)
        }
    }
}

struct HistoryDestination: View {
    @Query private var ideas: [Idea]

    init(ideaID: UUID) {
        _ideas = Query(filter: #Predicate<Idea> { $0.id == ideaID })
    }

    var body: some View {
        if let idea = ideas.first {
            EvaluationHistoryView(idea: idea)
        } else {
            EmptyState(symbol: "questionmark", title: "Idea not found", message: "It may have been removed.")
                .background(ForgeColor.canvas)
        }
    }
}

struct RoundDestination: View {
    @Query private var rounds: [Round]

    init(roundID: UUID) {
        _rounds = Query(filter: #Predicate<Round> { $0.id == roundID })
    }

    var body: some View {
        if let round = rounds.first {
            HearThePanelView(round: round)
        } else {
            EmptyState(symbol: "questionmark", title: "Round not found", message: "It may have been removed.")
                .background(ForgeColor.canvas)
        }
    }
}

struct CriteriaDestination: View {
    @Query private var ideas: [Idea]

    init(ideaID: UUID) {
        _ideas = Query(filter: #Predicate<Idea> { $0.id == ideaID })
    }

    var body: some View {
        if let idea = ideas.first, let evaluation = idea.latestEvaluation {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                    RingsRow(evaluation: evaluation)
                    PatternLegend(breakdown: evaluation.confidenceBreakdown)
                    CriteriaList(evaluation: evaluation)
                    Text("Each row opens the criterion: its rubric, the ladder, and the evidence behind the score. Scores change here, never from a ruling.")
                        .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Criteria")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            EmptyState(symbol: "questionmark", title: "No evaluation yet", message: "The panel has not scored this idea.")
                .background(ForgeColor.canvas)
        }
    }
}
