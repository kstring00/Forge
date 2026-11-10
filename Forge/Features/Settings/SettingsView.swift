import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import StoreKit
import ForgeCore

/// Settings, ready for the App Store (decision 0039): Membership, AI and
/// privacy, what the panel knows about you, backup, look and feel, about.
/// Costs, the server address and data counts live under Developer, Debug only.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query private var ideas: [Idea]
    @Query private var projects: [Project]
    @Query(sort: \RealityCheck.createdAt, order: .reverse) private var checks: [RealityCheck]

    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(QuotesPreference.key) private var quotesRaw: String = QuotesSetting.all.rawValue
    @AppStorage(PanelMemory.noteKey) private var panelNote: String = ""
    @State private var editingNote = false
    @State private var noteDraft = ""
    @AppStorage(AIConsent.storageKey) private var consentStamp: Double = 0
    @AppStorage(AISpend.ceilingKey) private var ceiling: Double = AISpend.defaultCeiling
    @AppStorage(AISpend.totalKey) private var spentThisMonth: Double = 0
    @AppStorage(AISpend.monthKey) private var spendMonth: String = ""
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var managingSubscription = false
    @State private var showingPrivacy = false
    @Environment(\.openURL) private var openURL
    @AppStorage(AppEnvironment.tightFairUseKey) private var tightFairUse = false

    private var liveCount: Int { ideas.filter { !$0.isArchived }.count }
    private var archivedCount: Int { ideas.count - liveCount }

    var body: some View {
        List {
            Section {
                LabeledContent("Plan", value: env.entitlements.state.plan.displayName
                               + (env.entitlements.state.isTrial ? " · free trial" : "")
                               + (env.entitlements.state.founding ? " · founding member" : ""))
                // Decision 0043: a booked switch, a cancel, or a payment problem, in plain words.
                if env.entitlements.state.plan != .free || env.entitlements.state.billing.hasIssue {
                    Text(env.entitlements.state.statusLine(date: { $0.formatted(.dateTime.month(.abbreviated).day()) }))
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
                // Decision 0042: what can be spent, in the order it is spent.
                let b = env.entitlements.balance
                if b.firstFreeAvailable {
                    LabeledContent("First check", value: "Free on this phone")
                }
                if b.rolledOverLeft > 0 {
                    LabeledContent("Carried over", value: "\(b.rolledOverLeft) · expire \(b.expiresText)")
                }
                LabeledContent("This month", value: "\(b.monthlyLeft) of \(b.monthlyAllowance) · resets \(b.expiresText)")
                if b.topUps > 0 {
                    LabeledContent("Extra", value: "\(b.topUps) · never expire")
                }
                Text("Carried-over checks are used first, then this month's, then extra ones. Unused checks carry into next month, up to one month's worth.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                Button("Plans and checks") { env.showingMembership = true }
                Button("Restore purchases") { Task { await env.membership.restore() } }
                if env.entitlements.state.plan != .free {
                    Button("Manage subscription") { managingSubscription = true }
                }
                if let message = env.membership.message {
                    Text(message).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
            } header: {
                Text("Membership")
            } footer: {
                Text("Your ideas, steps and Journal are yours on every plan. A check that fails or is stopped never counts.")
            }

            Section {
                if consentStamp > 0 {
                    LabeledContent("AI sharing", value: "Agreed \(Date(timeIntervalSince1970: consentStamp).formatted(date: .abbreviated, time: .omitted))")
                    Button("Withdraw consent", role: .destructive) {
                        AIConsent.withdraw()
                        consentStamp = 0
                    }
                } else {
                    LabeledContent("AI sharing", value: "Not yet agreed")
                }
                DisclosureGroup("What is sent") {
                    ForEach(AIConsent.whatIsSent, id: \.self) { Text($0).font(.footnote) }
                    Text("Never sent").forgeLabel().padding(.top, ForgeSpacing.xs)
                    ForEach(AIConsent.neverSent, id: \.self) { Text($0).font(.footnote) }
                }
                Button("Privacy policy") {
                    if let url = LegalLinks.privacy { openURL(url) } else { showingPrivacy = true }
                }
            } header: {
                Text("AI and privacy")
            } footer: {
                Text("Your ideas stay on this phone. An idea's text goes to an AI model through Hunch's server only when you tap an AI action, and only for that idea. You'll be asked before the first time.")
            }

            Section {
                if panelNote.isEmpty {
                    Text("Nothing yet. After three recorded outcomes, Hunch writes a short note from your record and shares it with the panel.")
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                } else {
                    Text(panelNote).font(.footnote)
                    if PanelMemory.edited {
                        Text("Edited by you. It stays as you wrote it until you reset it.").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    } else if let at = PanelMemory.generatedAt {
                        Text("Written from your record \(at.formatted(date: .abbreviated, time: .omitted)).").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                Button("Edit the note") { noteDraft = panelNote; editingNote = true }
                Button("Reset", role: .destructive) { PanelMemory.reset(); panelNote = "" }.disabled(panelNote.isEmpty && !PanelMemory.edited)
                NavigationLink("Your patterns") { PatternsView() }
            } header: {
                Text("What the panel knows about you")
            } footer: {
                Text(PanelMemory.label + " Under 80 words; sent with every call to the panel.")
            }

            Section {
                Button {
                    export()
                } label: {
                    Label(isExporting ? "Exporting…" : "Export your ideas", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting || ideas.isEmpty)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share \(exportURL.lastPathComponent)", systemImage: "folder")
                    }
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Import an export…", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Export saves every idea, step and voice note to a folder you can keep in Files or AirDrop. Import adds anything that isn't already here; nothing is overwritten or deleted.")
            }

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Daily quote", selection: $quotesRaw) {
                    ForEach(QuotesSetting.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
            } header: {
                Text("Look and feel")
            } footer: {
                Text("Dark is the default. The daily quote sits at the top of the Ideas tab, always with its source.")
            }

            Section {
                Button { sendFeedback() } label: { Label("Send feedback", systemImage: "envelope") }
                Button { openURL(LegalLinks.terms) } label: { Label("Terms of use", systemImage: "doc.text") }
                LabeledContent("Version", value: Self.versionString)
            } header: {
                Text("About")
            } footer: {
                Text("Feedback goes to \(Self.feedbackAddress) with the app version, so we can find what you saw.")
            }

            #if DEBUG
            Section {
                Button("Replay first run") { env.firstRun.startReplay() }
                    .foregroundStyle(ForgeColor.emberText)
                Button("Give checks back") { (env.entitlements as? LocalEntitlements)?.resetForTesting() }
                    .foregroundStyle(ForgeColor.emberText)
                Button("Start the next cycle (test rollover)") { (env.entitlements as? LocalEntitlements)?.startNextCycleForTesting() }
                    .foregroundStyle(ForgeColor.emberText)
                Toggle("Tight fair use (1 a day)", isOn: $tightFairUse)
                    .onChange(of: tightFairUse) { _, _ in AppEnvironment.reloadRules() }
                LabeledContent("Server", value: AIConsent.proxyURL ?? "Not configured")
                Picker("Your AI cost cap", selection: $ceiling) {
                    ForEach([5.0, 10.0, 25.0, 50.0, 100.0], id: \.self) { Text(AISpend.format($0)).tag($0) }
                }
                // Decision 0042, H: what checks really cost, by stage, and how much the cache saves.
                if let m = CostMeterStore.meter.summary {
                    LabeledContent("Per check (last \(m.checks))", value: RealityCheckCost.cents(m.perCheckUSD))
                    LabeledContent("Research · scoring · Brief", value: [m.researchUSD, m.scoringUSD, m.briefUSD].map(RealityCheckCost.cents).joined(separator: " · "))
                    LabeledContent("Cache hit rate", value: "\(Int((m.cacheHitRate * 100).rounded()))% of prompt tokens")
                    LabeledContent("Included follow-ups", value: m.perFollowUpUSD.map { "\(RealityCheckCost.cents($0)) avg · \(m.followUps)" } ?? "none yet")
                } else {
                    LabeledContent("Cost meter", value: "Run a check to start")
                }
                let month = RealityCheckCost.month(checks.map { (date: $0.createdAt, costUSD: $0.actualCostUSD) })
                LabeledContent("Checks this month", value: "\(month.count) · \(AISpend.format(month.spentUSD))")
                if let avg = RealityCheckCost.average(ofRecent: checks.compactMap(\.actualCostUSD)) {
                    LabeledContent("Average per check", value: RealityCheckCost.cents(avg))
                }
                LabeledContent("All AI this month", value: AISpend.format(spendMonth == AISpend.currentMonth() ? spentThisMonth : 0))
                LabeledContent("Ideas", value: "\(liveCount) live · \(archivedCount) archived · \(projects.count) projects")
                if let report = ProjectCleanup.lastReport() {
                    Text(report.line).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("Replay shows the welcome flow, the free-check screen and the first-Brief guide again without deleting anything. Give checks back restores this month's checks and the free first check; bought checks stay. Purchases here use Hunch.storekit: Debug → StoreKit → Manage Transactions refunds or expires them. The cost cap and the dollar figures are what the server reports for your own runs. Debug builds only; App Store builds are limited by the check allowance and the server's daily ceiling.")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(ForgeColor.canvas)
        .navigationTitle("Settings")
        .manageSubscriptionsSheet(isPresented: $managingSubscription)
        .sheet(isPresented: $showingPrivacy) { PrivacySummarySheet() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.folder, .json], allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .sheet(isPresented: $editingNote) {
            NavigationStack {
                Form {
                    Section {
                        TextField("About you, for the panel", text: $noteDraft, axis: .vertical).lineLimit(4...10)
                    } footer: {
                        Text("Under 80 words. \(PanelMemory.label)")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(ForgeColor.canvas)
                .navigationTitle("The note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingNote = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { PanelMemory.edit(noteDraft); panelNote = PanelMemory.note; editingNote = false }.fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: Export

    private func export() {
        isExporting = true
        defer { isExporting = false }
        do {
            let doc = try VaultExporter.document(from: context)
            exportURL = try VaultExporter.writeBundle(doc, to: FileManager.default.temporaryDirectory)
        } catch {
            show("Couldn't export", error.localizedDescription)
        }
    }

    // MARK: Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            show("Couldn't import", error.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                let jsonURL = isDirectory.boolValue ? url.appendingPathComponent(VaultExportDocument.fileName) : url
                guard FileManager.default.fileExists(atPath: jsonURL.path) else { throw ImportError.noVaultFile }
                let data = try Data(contentsOf: jsonURL)
                let doc = try VaultExporter.decode(data)
                let recordings = isDirectory.boolValue ? url.appendingPathComponent(VaultExportDocument.recordingsFolder) : nil
                let summary = try VaultImporter.importDocument(doc, into: context, recordingsFrom: recordings)
                show("Import finished", describe(summary))
            } catch {
                show("Couldn't import", (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private func describe(_ s: ImportSummary) -> String {
        var lines = ["\(s.ideasImported) \(s.ideasImported == 1 ? "idea" : "ideas") added."]
        if s.ideasSkipped > 0 { lines.append("\(s.ideasSkipped) already here, left as they were.") }
        if s.decisionsImported > 0 { lines.append("\(s.decisionsImported) decisions.") }
        if s.pitchesImported > 0 { lines.append("\(s.pitchesImported) pitches.") }
        if s.recordingsCopied > 0 { lines.append("\(s.recordingsCopied) recordings.") }
        return lines.joined(separator: " ")
    }

    private func show(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    private static var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    static let feedbackAddress = "kyle@stringhamwebdesign.com"

    /// TestFlight item 3: an email with the app and iOS versions already in it.
    private func sendFeedback() {
        let subject = "Hunch feedback (\(Self.versionString))"
        let body = "\n\n\n—\nHunch \(Self.versionString) · iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Self.feedbackAddress
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        if let url = c.url { openURL(url) }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(try! .forge(inMemory: true))

}
