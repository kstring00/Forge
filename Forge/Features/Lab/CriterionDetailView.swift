import SwiftUI
import SwiftData
import ForgeCore

/// One criterion: the teaching layer and the scoring controls. Definition with
/// its frameworks, the rubric as tappable anchors, the ladder as the evidence
/// picker, what does not count, the playbook, a note, and attached evidence.
struct CriterionDetailView: View {
    @Bindable var evaluation: Evaluation
    let criterion: Criterion
    @Environment(\.modelContext) private var context
    @State private var note = ""
    @State private var addingEvidence = false

    private var score: CriterionScore? { evaluation.criterionScore(for: criterion.key) }
    private var locked: Bool { evaluation.isFinal }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                header
                definition
                rubric
                ladder
                if criterion.scoreEqualsLadder { peopleCounter }
                doesNotCount
                playbook
                noteField
                evidenceList
                boundary
            }
            .padding(ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { note = score?.note ?? "" }
        .sheet(isPresented: $addingEvidence) {
            AddEvidenceSheet(evaluation: evaluation, criterion: criterion)
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("\(criterion.key) · \(criterion.frameworks.map(\.name).joined(separator: ", "))").forgeLabel().lineLimit(2)
            Text(criterion.title)
                .font(ForgeType.ideaTitleHero)
                .foregroundStyle(ForgeColor.ink)
            if let alias = criterion.alias {
                Text("Also called \(alias).").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            HStack(spacing: ForgeSpacing.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.map { String($0.score) } ?? "–").font(ForgeType.numeral).foregroundStyle(ForgeColor.ink)
                    Text("Score").forgeLabelSmall()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.map { String($0.evidenceLevel) } ?? "–").font(ForgeType.numeral).foregroundStyle(ForgeColor.emberText)
                    Text("Evidence rung").forgeLabelSmall()
                }
                Spacer()
                EvidenceChip(pattern: evaluation.pattern(for: criterion.key), size: 22)
            }
            if locked {
                Text("Version \(evaluation.version) is final. Start a new version from the idea to change it.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
    }

    private var definition: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("What it means").forgeLabel()
            Text(criterion.definition)
                .font(ForgeType.body)
                .foregroundStyle(ForgeColor.ink)
        }
    }

    private var rubric: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text(criterion.scoreEqualsLadder ? "Score · set by the ladder below" : "Score · tap the anchor that is true").forgeLabel()
            ForEach(1...5, id: \.self) { n in
                let anchor = criterion.rubric.anchor(for: n)
                Button {
                    guard !criterion.scoreEqualsLadder else { return }
                    setScore(n)
                } label: {
                    HStack(alignment: .top, spacing: ForgeSpacing.m) {
                        Text("\(n)")
                            .font(ForgeType.numeralSmall)
                            .foregroundStyle(score?.score == n ? ForgeColor.canvas : ForgeColor.ink)
                            .frame(width: 32, height: 32)
                            .background(score?.score == n ? ForgeColor.ink : ForgeColor.surface, in: Circle())
                            .overlay(Circle().strokeBorder(ForgeColor.line))
                        Text(anchor ?? "Between \(n - 1) and \(n + 1).")
                            .font(.system(size: 14))
                            .foregroundStyle(anchor == nil ? ForgeColor.inkSecondary : ForgeColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(ForgeSpacing.m)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous)
                        .strokeBorder(score?.score == n ? ForgeColor.ink : ForgeColor.line))
                }
                .buttonStyle(.plain)
                .disabled(locked || criterion.scoreEqualsLadder)
                .accessibilityLabel("Score \(n). \(anchor ?? "")")
                .accessibilityAddTraits(score?.score == n ? .isSelected : [])
            }
        }
    }

    private var ladder: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Evidence · tap the highest rung you have actually reached").forgeLabel()
            ForEach(criterion.ladder.reversed()) { rung in
                let selected = (score?.evidenceLevel ?? -1) == rung.level
                Button {
                    setEvidence(rung.level)
                } label: {
                    HStack(alignment: .top, spacing: ForgeSpacing.m) {
                        Text("\(rung.level)")
                            .font(ForgeType.numeralTiny)
                            .foregroundStyle(selected ? .white : ForgeColor.ink)
                            .frame(width: 24, height: 24)
                            .background(selected ? ForgeColor.ember : ForgeColor.surface, in: Circle())
                            .overlay(Circle().strokeBorder(selected ? ForgeColor.ember : ForgeColor.line))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rung.label).font(.system(size: 14, weight: .medium)).foregroundStyle(ForgeColor.ink)
                            Text(rung.description).font(.system(size: 12)).foregroundStyle(ForgeColor.inkSecondary)
                            Text(rung.worth).font(.system(size: 12)).foregroundStyle(ForgeColor.ink.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(ForgeSpacing.m)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous)
                        .strokeBorder(selected ? ForgeColor.ember : ForgeColor.line))
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .accessibilityLabel("Rung \(rung.level), \(rung.label)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// A2 only: the score is the highest rung reached by at least three independent people.
    private var peopleCounter: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Independent people at this rung").forgeLabel()
            HStack {
                Stepper(value: Binding(get: { score?.peopleAtRung ?? 0 }, set: { setPeople($0) }), in: 0...99) {
                    Text("\(score?.peopleAtRung ?? 0) of 3 needed")
                        .font(ForgeType.body).foregroundStyle(ForgeColor.ink)
                }
                .disabled(locked)
            }
            Text("Not family, not close friends, not three people from one conversation. One person at a high rung is a promising signal; it does not move the score.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
        }
    }

    private var doesNotCount: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("What does not count").forgeLabel()
            ForEach(criterion.doesNotCount, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: ForgeSpacing.s) {
                    Text("•").foregroundStyle(ForgeColor.inkSecondary)
                    Text(item).font(.system(size: 14)).foregroundStyle(ForgeColor.ink)
                }
            }
        }
    }

    private var playbook: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("How to find it this week").forgeLabel()
            ForEach(Array(criterion.playbook.enumerated()), id: \.offset) { i, step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(i + 1). \(step.title)").font(.system(size: 14, weight: .medium)).foregroundStyle(ForgeColor.ink)
                        Spacer()
                        Text("Rung \(step.reachesRung) · \(step.effort)").forgeLabelSmall()
                    }
                    Text(step.body).font(.system(size: 13)).foregroundStyle(ForgeColor.ink.opacity(0.85))
                }
                .padding(ForgeSpacing.m)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Your note · shown on the criterion row").forgeLabel()
            TextField("One line on why this score", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .font(ForgeType.body)
                .padding(ForgeSpacing.m)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                .disabled(locked)
                .onChange(of: note) { _, new in
                    guard !locked, let score else { return }
                    score.note = new
                }
        }
    }

    private var evidenceList: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text("Evidence attached").forgeLabel()
                Spacer()
                if !locked {
                    Button { addingEvidence = true } label: { Label("Attach", systemImage: "plus").font(.caption.weight(.medium)) }
                        .foregroundStyle(ForgeColor.ink)
                        .disabled(score == nil)
                }
            }
            if let items = score?.evidence.sorted(by: { $0.createdAt < $1.createdAt }), !items.isEmpty {
                ForEach(items) { ev in
                    HStack(alignment: .top, spacing: ForgeSpacing.m) {
                        EvidenceChip(pattern: EvidencePattern(ev.source?.sourceClass ?? .assumption), size: 14).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ev.text).font(.system(size: 14)).foregroundStyle(ForgeColor.ink)
                            HStack(spacing: ForgeSpacing.s) {
                                Text("Rung \(ev.ladderRung)").forgeLabelSmall()
                                if let s = ev.source {
                                    Text(s.sourceClass.displayName).forgeLabelSmall()
                                    if let url = s.url, !url.isEmpty { Text(url).font(.caption2).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1) }
                                }
                            }
                        }
                    }
                    .padding(ForgeSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                }
            } else {
                Text(score == nil ? "Score the criterion first, then attach what you have." : "Nothing attached. The rung above is your word until something is.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
    }

    private var boundary: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            HStack(spacing: ForgeSpacing.xs) { SparkGlyph(); Text("What the AI may do here").forgeLabel() }
            Text(criterion.aiBoundary).font(ForgeType.aiText).foregroundStyle(ForgeColor.spark)
        }
    }

    // MARK: Mutations

    private func setScore(_ n: Int) {
        try? evaluation.set(key: criterion.key, score: n, evidenceLevel: score?.evidenceLevel ?? 0, note: note)
        evaluation.idea?.touch()
    }

    private func setEvidence(_ level: Int) {
        if criterion.scoreEqualsLadder {
            let people = score?.peopleAtRung ?? 0
            try? evaluation.set(key: criterion.key, score: Scoring.demandScore(peopleAtRung: [level: people]), evidenceLevel: level, note: note)
        } else {
            try? evaluation.set(key: criterion.key, score: score?.score ?? 1, evidenceLevel: level, note: note)
        }
        evaluation.idea?.touch()
    }

    private func setPeople(_ n: Int) {
        guard let score else { return }
        score.peopleAtRung = n
        if criterion.scoreEqualsLadder {
            try? evaluation.set(key: criterion.key, score: Scoring.demandScore(peopleAtRung: [score.evidenceLevel: n]), evidenceLevel: score.evidenceLevel, note: note)
        }
        evaluation.idea?.touch()
    }
}

/// Manual evidence (Phase 3): a note or a link, as verified or assumption, at a
/// rung the user picks. The rung is bounded by what the source can prove: a
/// link alone never exceeds rung 2. AI-found evidence arrives in Phase 4.
struct AddEvidenceSheet: View {
    @Bindable var evaluation: Evaluation
    let criterion: Criterion
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var url = ""
    @State private var sourceClass: SourceClass = .userVerified
    @State private var rung = 2

    private var isLink: Bool { !url.trimmingCharacters(in: .whitespaces).isEmpty }
    private var rungCeiling: Int { isLink && sourceClass != .userVerified ? Scoring.deskResearchRungCeiling : 5 }
    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("The claim") {
                    TextField("What this shows, in one line", text: $text, axis: .vertical).lineLimit(1...4)
                    TextField("Link (optional)", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Picker("Who vouches", selection: $sourceClass) {
                        Text("I read it or lived it").tag(SourceClass.userVerified)
                        Text("My belief, unverified").tag(SourceClass.assumption)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Source class")
                } footer: {
                    Text("Assumptions never raise Confidence. Verified evidence does, at the rung you pick.")
                }
                Section {
                    Picker("Rung", selection: $rung) {
                        ForEach(criterion.ladder.filter { $0.level <= rungCeiling }) { r in
                            Text("\(r.level) · \(r.label)").tag(r.level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Rung this supports")
                } footer: {
                    Text(rungCeiling < 5 ? "A page you have not lived proves the market exists, rung 2 at most. Rungs 3 to 5 are things people did for you." : "Pick the rung the evidence actually reaches, not the one you hope for.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ForgeColor.canvas)
            .navigationTitle("Attach evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Attach") { save(); dismiss() }.disabled(!canSave).fontWeight(.semibold)
                }
            }
            .onChange(of: rungCeiling) { _, c in rung = min(rung, c) }
        }
    }

    private func save() {
        guard let score = evaluation.criterionScore(for: criterion.key), let idea = evaluation.idea else { return }
        let source = Source(kind: isLink ? .web : .note, title: String(text.prefix(60)), fullText: text,
                            sourceClass: sourceClass, url: isLink ? url.trimmingCharacters(in: .whitespaces) : nil)
        source.reviewed = sourceClass == .userVerified
        idea.sources.append(source)
        let evidence = Evidence(criterionKey: criterion.key, ladderRung: min(rung, rungCeiling), text: text, source: source)
        score.evidence.append(evidence)
        if evidence.countsTowardConfidence, evidence.ladderRung > score.evidenceLevel {
            try? evaluation.set(key: criterion.key, score: score.score, evidenceLevel: evidence.ladderRung, note: score.note)
        }
        idea.touch()
    }
}
