import SwiftUI
import SwiftData
import ForgeCore

/// The full Brief as its own screen, reached from "The panel's take" on the
/// idea page and from a Reality project page. "Not quite" goes back to the
/// idea page, where the Lab is.
struct BriefView: View {
    @Bindable var idea: Idea
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                if idea.latestRealityCheck != nil {
                    BriefSection(idea: idea) { dismiss() }
                } else {
                    EmptyState(symbol: "circle.hexagonpath", title: "No Brief yet",
                               message: "The panel has not checked this idea. Send it from the idea page.")
                }
            }
            .padding(ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .navigationTitle("The Brief")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { env.realityChecks.markSeen(idea.id) }
    }
}
