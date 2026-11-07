import SwiftUI
import SwiftData
import ForgeCore

/// One idea. The original text is read-only and visibly so; title, lens,
/// stage, tags and notes are the user's to edit.
struct IdeaDetailView: View {
    @Bindable var idea: Idea
    @Environment(\.dismiss) private var dismiss
    @State private var tagText = ""
    @State private var confirmingArchive = false
    @State private var converting = false
    @State private var playback = AudioPlayback()

    private var audioURL: URL? {
        guard let name = idea.audioFileName, RecordingStore.exists(name) else { return nil }
        return RecordingStore.url(for: name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                GrainGradient(colors: ForgeColor.sky(for: idea.stage))
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))

                TextField("Title", text: $idea.title, axis: .vertical)
                    .font(ForgeType.ideaTitleHero)
                    .foregroundStyle(ForgeColor.ink)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Idea title")

                metadata

                original

                if let summary = idea.aiSummary, idea.aiSummaryConfirmed {
                    AIText(text: summary)
                }

                ExploreSection(idea: idea)

                makeItReal

                tags

                notes

                footer
            }
            .padding(ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if idea.isArchived {
                        Button { idea.unarchive() } label: { Label("Bring back", systemImage: "arrow.uturn.backward") }
                    } else {
                        Button { confirmingArchive = true } label: { Label("Archive", systemImage: "archivebox") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("More")
                }
            }
        }
        .confirmationDialog("Archive this idea?", isPresented: $confirmingArchive, titleVisibility: .visible) {
            Button("Archive") {
                idea.archive()
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("It moves out of the Vault but nothing is deleted. You can bring it back any time.")
        }
        .sheet(isPresented: $converting) { ConvertToProjectSheet(idea: idea) }
        .onAppear { tagText = idea.tags.joined(separator: ", ") }
        .onDisappear { playback.stop() }
        .onChange(of: idea.title) { idea.touch() }
        .onChange(of: idea.notes) { idea.touch() }
    }

    // MARK: Sections

    private var metadata: some View {
        HStack(spacing: ForgeSpacing.m) {
            Menu {
                Button("No lens yet") { idea.lensType = nil }
                ForEach(LensType.allCases) { lens in
                    Button(lens.displayName) { idea.lensType = lens }
                }
            } label: {
                pill(idea.lensType?.displayName ?? "Choose a lens", tint: ForgeColor.lensTint(idea.lensType))
            }
            .accessibilityLabel("Lens")

            Menu {
                ForEach(Stage.allCases.filter { $0 != .archived }, id: \.self) { stage in
                    Button(stage.displayName) { idea.stage = stage }
                }
            } label: {
                pill(idea.stage.displayName, tint: ForgeColor.inkSecondary)
            }
            .accessibilityLabel("Stage")

            Spacer()
        }
    }

    private func pill(_ text: String, tint: Color) -> some View {
        HStack(spacing: ForgeSpacing.xs) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(text).font(.caption.weight(.medium))
            Image(systemName: "chevron.down").font(.caption2)
        }
        .foregroundStyle(ForgeColor.ink)
        .padding(.horizontal, ForgeSpacing.m)
        .padding(.vertical, ForgeSpacing.s)
        .background(ForgeColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(ForgeColor.line))
    }

    private var original: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(spacing: ForgeSpacing.s) {
                Text("Original").forgeLabel()
                Image(systemName: "lock")
                    .font(.caption2)
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .accessibilityLabel("Cannot be edited")
                if idea.audioFileName != nil {
                    Text("· voice").forgeLabel()
                }
                Spacer()
                if let audioURL {
                    Button {
                        playback.toggle(audioURL)
                    } label: {
                        Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(ForgeColor.ink)
                    }
                    .accessibilityLabel(playback.isPlaying ? "Pause recording" : "Play recording")
                }
            }
            OriginalText(text: idea.originalText)
                .padding(.vertical, ForgeSpacing.xs)
        }
    }

    @ViewBuilder
    private var makeItReal: some View {
        if let project = idea.project {
            NavigationLink(value: WorkshopRoute.project(project.id)) {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    Text("In the Workshop").forgeLabel()
                    Text(project.name)
                        .font(ForgeType.ideaTitle)
                        .foregroundStyle(ForgeColor.ink)
                    if let next = project.nextStep, project.status == .active {
                        Text("Next: \(next)")
                            .font(ForgeType.secondary)
                            .foregroundStyle(ForgeColor.ink)
                            .lineLimit(2)
                    }
                }
                .padding(ForgeSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
            }
            .buttonStyle(.plain)
        } else if !idea.isArchived {
            Button { converting = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                        Text("Make it real")
                            .font(ForgeType.ideaTitle)
                            .foregroundStyle(ForgeColor.ink)
                        Text("Commit to one next step and say what launched means. No evaluation required.")
                            .font(.caption)
                            .foregroundStyle(ForgeColor.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(ForgeColor.ink)
                }
                .padding(ForgeSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Make it real")
        }
    }

    private var tags: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Tags").forgeLabel()
            TextField("comma, separated", text: $tagText)
                .font(ForgeType.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(commitTags)
                .onChange(of: tagText) { commitTags() }
                .padding(ForgeSpacing.m)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                .accessibilityLabel("Tags")
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Notes").forgeLabel()
            TextEditor(text: $idea.notes)
                .font(ForgeType.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(ForgeSpacing.s)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                .accessibilityLabel("Notes")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            Text("Captured \(idea.createdAt.formatted(date: .abbreviated, time: .shortened))")
            Text("Updated \(idea.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            if idea.isArchived, let at = idea.archivedAt {
                Text("Archived \(at.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .font(.caption)
        .foregroundStyle(ForgeColor.inkSecondary)
    }

    private func commitTags() {
        let parsed = Idea.parseTags(tagText)
        if parsed != idea.tags {
            idea.tags = parsed
            idea.touch()
        }
    }
}
