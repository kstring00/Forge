import SwiftUI
import ForgeCore

/// The one idea card (decision 0025), on Ideas and wherever a list needs it.
/// A thin sky band keyed to stage, the spark, the track line with the step's
/// progress, a serif title, then at most two lines: the verdict word on its
/// own line and the Est. return figure beneath it.
struct IdeaCard: View {
    let idea: Idea
    var status: IdeaStatus? = nil
    var compact = false
    /// The header opens the idea (or its step); the primary action sits under it.
    var linked = true
    var showsAction = true

    private var resolved: IdeaStatus { status ?? IdeaStatus.of(idea) }
    private var track: Track? { idea.track }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(colors: ForgeColor.sky(for: idea.stage), startPoint: .leading, endPoint: .trailing)
                .frame(height: 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                if linked {
                    Group {
                        if let project = idea.project {
                            NavigationLink(value: WorkshopRoute.project(project.id)) { header }
                        } else {
                            NavigationLink(value: VaultRoute.idea(idea.id)) { header }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    header
                }
                // Full width under the header, outside its link: the meters, the estimate, the What-if.
                statusBlock
                if showsAction { CardPrimaryAction(idea: idea) }
            }
            .padding(ForgeSpacing.cardPadding)
        }
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line, lineWidth: 1))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            IdeaSpark(idea: idea, size: 44)
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                HStack(spacing: ForgeSpacing.m) {
                    Text(topLine).forgeLabelSmall().lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    StageTrail(track: track)
                }
                Text(idea.title)
                    .font(ForgeType.ideaTitle)
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(2)
                IdeaSubtitle(idea: idea)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// "Reality · 2 of 5" / "Formation · Ruled 3 of 5" / "Idea · Business".
    private var topLine: String {
        var parts = [track?.displayName ?? "Archived"]
        if let project = idea.project, project.nextStep != nil, project.status == .active {
            parts.append("\(min(project.nextStepCount, project.effectiveTarget)) of \(project.effectiveTarget)")
        } else if let project = idea.project, project.status != .active {
            parts.append(project.status == .done ? "Launched" : project.status == .paused ? "Paused" : "Archived")
        } else if let round = idea.rounds.max(by: { $0.createdAt < $1.createdAt }), !round.verdicts.isEmpty {
            let tally = RoundTally(round.verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) })
            parts.append(tally.isComplete ? "Ruled" : "Ruled \(tally.ruled) of \(tally.total)")
        } else if let lens = idea.lensType {
            parts.append(lens.displayName)
        }
        if idea.triage?.isComplete == true { parts.append("Screened") }
        return parts.joined(separator: " · ")
    }

    /// Never more than two lines.
    @ViewBuilder
    private var statusBlock: some View {
        switch resolved {
        case .notChecked:
            HStack(spacing: ForgeSpacing.s) {
                Text(idea.track == .reality ? "No panel yet" : "Not yet checked").forgeLabel()
                Spacer()
                Text(idea.createdAt, style: .date).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
        case .checking:
            HStack(spacing: ForgeSpacing.s) {
                ProgressView().controlSize(.mini)
                Text("Checking").forgeLabel()
            }
        case .checkFailed:
            HStack(spacing: ForgeSpacing.s) {
                Image(systemName: "exclamationmark.circle").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                Text("Check failed · open to see why").forgeLabel()
            }
        case .impact:
            EstimatedReturnRow(idea: idea)
        case .checked:
            // Decision 0038: words and shapes, not bare numbers; then the panel's best What-if.
            VStack(alignment: .leading, spacing: 12) {
                CardMeters(idea: idea)
                EstimatedReturnRow(idea: idea)
                WhatIfTeaser(idea: idea)
            }
            .padding(.top, 4)
        }
    }

    private var accessibilityText: String {
        var parts = [idea.title, topLine]
        switch resolved {
        case .notChecked: parts.append(idea.track == .reality ? "no panel yet" : "not yet checked")
        case .checking: parts.append("checking")
        case .checkFailed: parts.append("the last Reality Check failed")
        case .impact: parts.append("judged by impact")
        case .checked(let v, _): parts.append("\(v.displayName), \(ProofStage.of(idea).label)")
        }
        return parts.joined(separator: ", ")
    }
}

/// A 22pt Confidence ring for cards.
struct MiniRing: View {
    let value: Int
    var tint: Color = ForgeColor.ember

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(ForgeColor.line, lineWidth: 3)
                Circle().trim(from: 0, to: Double(min(max(value, 0), 100)) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            Text("\(value)").font(ForgeType.numeralTiny).foregroundStyle(ForgeColor.ink)
        }
        .accessibilityLabel("Confidence \(value)")
    }
}

/// The person's own words under a short title: one muted line.
struct IdeaSubtitle: View {
    let idea: Idea

    private var words: String {
        idea.originalText.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
    }

    var body: some View {
        if !words.isEmpty && words != idea.title {
            Text(words).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(3)
        }
    }
}
