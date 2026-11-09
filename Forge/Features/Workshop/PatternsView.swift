import SwiftUI
import SwiftData
import ForgeCore

/// "Your patterns": the user's record against each Sphere, the criteria they
/// habitually over- or under-score, and a plain-language summary. Reached from
/// Home and the Journal. Shows nothing until three outcomes are recorded,
/// rather than guessing. Refreshes the about-you note the panel reads.
struct PatternsView: View {
    @Query private var ideas: [Idea]

    private var patterns: Patterns { Patterns(RulingActions.settled(in: ideas)) }
    private var lens: Lens { Lenses.business }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                Text("Your patterns").font(ForgeType.ideaTitleHero).foregroundStyle(ForgeColor.ink)
                if !patterns.hasEnough {
                    waiting
                } else {
                    summary
                    spheres
                    if !patterns.tendencies.isEmpty { tendencies }
                    note
                }
            }
            .padding(ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .navigationTitle("Your patterns")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { PanelMemory.refresh(from: patterns, lens: lens) }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("\(patterns.outcomes) of \(Patterns.minimumOutcomes) outcomes recorded.").font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
            Text("When you record what happened on an idea, Hunch asks which of the panel's points it settled. After three, your record appears here: which voices you overrule and how that turns out, and which criteria you score high or low. Nothing is guessed before then.")
                .font(.system(.subheadline)).foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("In plain words").forgeLabel()
            ForEach(patterns.summary(lens: lens), id: \.self) { line in
                Text(line).font(ForgeType.statement).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            }
            Text("\(patterns.outcomes) outcomes recorded.").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        }
    }

    private var spheres: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Your record against each voice").forgeSubhead()
            ForEach(patterns.spheres, id: \.sphere) { r in
                HStack(spacing: 12) {
                    OrbView(sphere: r.sphere, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.sphere.displayName).font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                        Text(r.settled == 0 ? "Nothing settled yet" : "Overruled \(r.overruled) \(r.overruled == 1 ? "time" : "times") · \(r.sphere.displayName) right \(r.sphereRight) · you right \(r.userRight)")
                            .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
            }
        }
    }

    private var tendencies: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Criteria you lean on").forgeSubhead()
            ForEach(patterns.tendencies, id: \.key) { t in
                HStack {
                    Text(lens.criterion(t.key)?.title ?? t.key).font(.system(.subheadline)).foregroundStyle(ForgeColor.ink)
                    Spacer()
                    Text(t.lean > 0 ? "Scored high · \(t.cases)" : "Scored low · \(t.cases)").forgeLabelSmall().foregroundStyle(ForgeColor.emberText)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(ForgeColor.line).frame(height: 1) }
            }
            Text("Your Potential score on the criterion against what the outcome showed.").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        }
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("What the panel is told").forgeSubhead()
            Text(PanelMemory.note.isEmpty ? patterns.aboutNote(lens: lens) : PanelMemory.note)
                .font(ForgeType.aiText).foregroundStyle(ForgeColor.ink)
            Text(PanelMemory.label).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            NavigationLink { SettingsView() } label: {
                Text("Read, edit or reset it in Settings").font(.footnote.weight(.medium)).foregroundStyle(ForgeColor.ink)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}
