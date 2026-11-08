import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0030: the drafted questions, fillable. "Who did you talk to?",
/// then each question with a typed answer and a mic. Questions can be edited,
/// reordered and deleted first. The draft saves itself. Done is one logged
/// conversation: a user-verified source with every Q&A, the count advances,
/// the rung is confirmed, the Journal gets its line. Past interviews open here
/// read-only.
struct InterviewSheet: View {
    @Bindable var project: Project
    var readOnly: Interview? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var interview: Interview
    @State private var questions: [String]
    @State private var editingQuestions = false
    @State private var newQuestion = ""
    @State private var finishing = false
    @State private var rung: Int?
    @State private var copied = false

    init(project: Project, readOnly: Interview? = nil) {
        self.project = project
        self.readOnly = readOnly
        let qs = project.interviewQuestions ?? InterviewQuestions.fallback
        _questions = State(initialValue: qs)
        _interview = State(initialValue: readOnly ?? project.interviews.last(where: { $0.isDraft }) ?? Interview(questions: qs))
    }

    private var isReadOnly: Bool { readOnly != nil }
    private var guess: Int { RungInference.infer(interview.transcript)?.rung ?? 3 }
    private var effectiveRung: Int { max(3, rung ?? guess) }

    var body: some View {
        NavigationStack {
            Group {
                if editingQuestions { questionEditor } else { answering }
            }
            .background(ForgeColor.canvas)
            .navigationTitle(isReadOnly ? "Conversation" : (editingQuestions ? "Questions" : "Interview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear {
                // Seed the question list from the panel's asset once, so editing starts from it.
                if project.interviewQuestions == nil && !isReadOnly {
                    questions = WorkshopActions.interviewQuestions(for: project)
                    if interview.answers.isEmpty { interview = Interview(questions: questions) }
                }
            }
            .onChange(of: interview) { _, i in
                if !isReadOnly { WorkshopActions.saveDraft(i, on: project) }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Answering

    private var answering: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                if let step = project.nextStep {
                    Text(step).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
                who
                ForEach(Array(interview.answers.enumerated()), id: \.offset) { i, a in
                    questionCard(i, a)
                }
                if isReadOnly {
                    if let r = interview.rung {
                        Text("Counted as one conversation · \(RungInference.label(r)) · \(Plain.rung(r))").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    }
                } else {
                    finish
                }
            }
            .padding(ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var who: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Who did you talk to?").forgeSubhead()
            if isReadOnly {
                Text(interview.headline).font(ForgeType.body).foregroundStyle(ForgeColor.ink)
            } else {
                field("Name or nickname", text: $interview.who)
                field("Who they are · runs a daycare in Katy", text: $interview.whoIs)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(ForgeColor.inkSecondary))
            .font(ForgeType.body)
            .padding(ForgeSpacing.m)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
            .accessibilityLabel(placeholder)
    }

    private func questionCard(_ i: Int, _ a: Interview.Answer) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Question \(i + 1) of \(interview.answers.count)").forgeLabel()
            Text(a.question).forgeSubhead()
            if isReadOnly {
                Text(a.answer.isEmpty ? "Not asked." : a.answer)
                    .font(ForgeType.body).foregroundStyle(a.answer.isEmpty ? ForgeColor.inkSecondary : ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                AnswerField(text: $interview.answers[i].answer)
            }
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    /// Done → confirm the rung → saved as one conversation.
    @ViewBuilder
    private var finish: some View {
        if finishing {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text("What did they give?").forgeSubhead()
                HStack(spacing: 8) {
                    ForEach([3, 4, 5], id: \.self) { r in
                        let on = effectiveRung == r
                        Button { rung = r } label: {
                            Text(RungInference.label(r))
                                .font(.system(.footnote, weight: .medium))
                                .foregroundStyle(on ? .white : ForgeColor.ink)
                                .padding(.horizontal, 12).frame(height: 32)
                                .background(on ? ForgeColor.ember : ForgeColor.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(on ? Color.clear : ForgeColor.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Text("\(Plain.rung(effectiveRung).prefix(1).uppercased() + Plain.rung(effectiveRung).dropFirst()). Saved as verified by you, counted as one of \(project.effectiveTarget), and written to the Journal.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                Button {
                    WorkshopActions.finishInterview(interview, rung: effectiveRung, on: project, in: context)
                    try? context.save()
                    dismiss()
                } label: {
                    Text("Save conversation")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        } else {
            Button { withAnimation(ForgeMotion.settle) { finishing = true } } label: {
                Text("Done")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(interview.hasContent ? ForgeColor.ember : ForgeColor.inkSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!interview.hasContent)
            Text(interview.hasContent ? "Done counts this as one conversation. Your draft is saved as you type; Close keeps it for later."
                                      : "Write who you talked to or one answer, and Done lights up. Your draft is saved as you type.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        }
    }

    // MARK: Editing the questions

    private var questionEditor: some View {
        List {
            Section {
                ForEach(questions.indices, id: \.self) { i in
                    TextField("Question", text: $questions[i], axis: .vertical).font(ForgeType.body)
                }
                .onDelete { questions.remove(atOffsets: $0) }
                .onMove { questions.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Drag to reorder, swipe to delete")
            } footer: {
                Text("Ask about the last time it happened and what they actually did. Not whether they'd use yours.")
            }
            Section {
                HStack {
                    TextField("Add a question", text: $newQuestion, axis: .vertical).font(ForgeType.body)
                    Button {
                        let q = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !q.isEmpty else { return }
                        questions.append(q); newQuestion = ""
                    } label: { Image(systemName: "plus.circle.fill").foregroundStyle(ForgeColor.ember) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add question")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    /// Back to answering: answers follow their questions; new ones start blank.
    private func applyQuestions() {
        WorkshopActions.setInterviewQuestions(project, questions)
        questions = project.interviewQuestions ?? InterviewQuestions.fallback
        let old = Dictionary(interview.answers.map { ($0.question, $0.answer) }, uniquingKeysWith: { a, _ in a })
        interview.answers = questions.map { Interview.Answer(question: $0, answer: old[$0] ?? "") }
        editingQuestions = false
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if editingQuestions {
                Button("Done") { applyQuestions() }.fontWeight(.semibold)
            } else {
                Button("Close") { dismiss() }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !editingQuestions {
                Menu {
                    if !isReadOnly {
                        Button { editingQuestions = true } label: { Label("Edit questions", systemImage: "pencil") }
                    }
                    ShareLink(item: isReadOnly ? interview.transcript : InterviewQuestions.plainText(questions, title: project.nextStep)) {
                        Label(isReadOnly ? "Share conversation" : "Share questions", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = isReadOnly ? interview.transcript : InterviewQuestions.plainText(questions, title: project.nextStep)
                        copied = true
                    } label: { Label(copied ? "Copied" : (isReadOnly ? "Copy conversation" : "Copy questions"), systemImage: "doc.on.doc") }
                    if !isReadOnly && interview.hasContent {
                        Divider()
                        Button(role: .destructive) {
                            WorkshopActions.discardDraft(interview, on: project)
                            dismiss()
                        } label: { Label("Discard draft", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("More")
                }
            }
        }
    }
}

/// One answer: typed or spoken. Its own focus so several can share a screen.
private struct AnswerField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        VoiceNoteField(label: "Their answer", text: $text, focused: $focused, minHeight: 72)
    }
}
