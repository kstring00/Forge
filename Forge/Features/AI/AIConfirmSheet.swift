import SwiftUI

/// Shown before every call to the proxy ("Credit moments" artboard, without
/// the credits): what will happen, how long it takes, that the idea text goes
/// to an AI model through the user's proxy, then Send or Cancel. Nothing is
/// sent until Send. The first Send also records the one-time consent that
/// Settings shows; the first time, the full list of what is and isn't sent is
/// on the sheet.
struct AIConfirmSheet: View {
    struct Content {
        /// Mono caps over the title: "Reality check", "Expand", "Re-score".
        var kind: String
        /// Serif question: "Send IntroBand to the panel?"
        var title: String
        /// What will happen, in one or two sentences.
        var whatHappens: String
        /// "Takes 1 to 3 minutes."
        var duration: String
        var sendTitle = "Send"
    }

    let content: Content
    var onDecision: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    private var firstTime: Bool { !AIConsent.isGranted }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                    Text(content.kind).forgeLabel().foregroundStyle(ForgeColor.emberText)
                    Text(content.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                    Text("\(content.whatHappens) \(content.duration)")
                        .font(ForgeType.body).foregroundStyle(ForgeColor.ink.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if firstTime {
                        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                            Text("Before FORGE talks to an AI").font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                            list("What is sent", AIConsent.whatIsSent)
                            list("Never sent", AIConsent.neverSent)
                            Text("Through \(AIConsent.proxyURL ?? "your proxy"). You can withdraw this in Settings, where the same list is shown.")
                                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                        }
                        .padding(ForgeSpacing.m)
                        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    } else {
                        Text("Your idea text is sent to an AI model through your proxy.")
                            .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    }

                    Button {
                        AIConsent.grant()
                        onDecision(true)
                        dismiss()
                    } label: {
                        Text(content.sendTitle)
                            .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, ForgeSpacing.s)

                    Button("Cancel") { onDecision(false); dismiss() }
                        .font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.inkSecondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(ForgeSpacing.l)
                .padding(.top, ForgeSpacing.s)
            }
            .background(ForgeColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents(firstTime ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }

    private func list(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).forgeLabelSmall()
            ForEach(items, id: \.self) { Text("· \($0)").font(.footnote).foregroundStyle(ForgeColor.ink) }
        }
    }
}

extension AIConfirmSheet.Content {
    static func realityCheck(ideaTitle: String) -> Self {
        .init(kind: "Reality check",
              title: "Send \(ideaTitle) to the panel?",
              whatHappens: "They'll research who already does this, weigh in from five angles, and hand you one real-world next step.",
              duration: "Takes 1 to 3 minutes.")
    }

    static let expand = Self(kind: "Expand",
                             title: "Clarify this thought?",
                             whatHappens: "The AI rewrites the rough thought as one clean paragraph in your intent, with a title and the questions a skeptical friend would ask. You confirm before anything is saved.",
                             duration: "Takes about ten seconds.")

    static let summarize = Self(kind: "Summarize",
                                title: "Summarize the Explore notes?",
                                whatHappens: "The AI turns your Explore answers into notes, decisions already implied, and open questions. You confirm before anything is saved.",
                                duration: "Takes about ten seconds.")

    static let rescore = Self(kind: "Re-score",
                              title: "Re-score what this touches?",
                              whatHappens: "What you wrote is already saved as verified by you. The panel re-reads the Library and re-scores only the criteria it touches, in a new version.",
                              duration: "Takes one to two minutes.",
                              sendTitle: "Send to the panel")
}
