import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ForgeCore

/// Settings. Phase 1b: export and import of the whole Vault. Later phases add
/// the AI-sharing disclosure, Advantages, Constraints and the Steward charter.
struct SettingsView: View {
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

    private var liveCount: Int { ideas.filter { !$0.isArchived }.count }
    private var archivedCount: Int { ideas.count - liveCount }

    var body: some View {
        List {
            Section {
                Button {
                    export()
                } label: {
                    Label(isExporting ? "Exporting…" : "Export Vault", systemImage: "square.and.arrow.up")
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
                Text("Export writes a folder with vault.json, vault.md and your voice recordings. Save it to Files or AirDrop it. Import adds anything that isn't already here; nothing is overwritten or deleted.")
            }

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Dark is the studio's default. Light inverts the same palette. Showing \(colorScheme == .dark ? "dark" : "light") now.")
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
                LabeledContent("Proxy", value: AIConsent.proxyURL ?? "Not configured")
                Picker("Monthly ceiling", selection: $ceiling) {
                    ForEach([5.0, 10.0, 25.0, 50.0, 100.0], id: \.self) { Text(AISpend.format($0)).tag($0) }
                }
            } header: {
                Text("AI")
            } footer: {
                Text("Sent only when you tap an AI action, only for that idea, through your own proxy. You'll be asked before the first call.")
            }

            Section {
                Picker("Quotes", selection: $quotesRaw) {
                    ForEach(QuotesSetting.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
            } header: {
                Text("Ideas tab")
            } footer: {
                Text("One line a day at the top of the Ideas tab. Every quote is attributed to a source you can check.")
            }

            Section {
                if panelNote.isEmpty {
                    Text("Nothing yet. After three recorded outcomes, FORGE writes a short note from your record and shares it with the panel.")
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                } else {
                    Text(panelNote).font(.footnote)
                    if PanelMemory.edited {
                        Text("Edited by you. It stays as you wrote it until you reset it.").font(.caption2).foregroundStyle(ForgeColor.inkSecondary)
                    } else if let at = PanelMemory.generatedAt {
                        Text("Written from your record \(at.formatted(date: .abbreviated, time: .omitted)).").font(.caption2).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                Button("Edit the note") { noteDraft = panelNote; editingNote = true }
                Button("Reset", role: .destructive) { PanelMemory.reset(); panelNote = "" }.disabled(panelNote.isEmpty && !PanelMemory.edited)
                NavigationLink("Your patterns") { PatternsView() }
            } header: {
                Text("What the panel knows about you")
            } footer: {
                Text(PanelMemory.label + " Under 80 words; sent with every Sphere call.")
            }

            Section {
                let month = RealityCheckCost.month(checks.map { (date: $0.createdAt, costUSD: $0.actualCostUSD) })
                LabeledContent("Reality Checks this month", value: "\(month.count)")
                LabeledContent("Their cost this month", value: AISpend.format(month.spentUSD))
                if let avg = RealityCheckCost.average(ofRecent: checks.compactMap(\.actualCostUSD)) {
                    LabeledContent("Average per check", value: RealityCheckCost.cents(avg))
                }
                if let last = checks.first(where: { ($0.actualCostUSD ?? 0) > 0 })?.actualCostUSD {
                    LabeledContent("Last check", value: RealityCheckCost.cents(last))
                }
                LabeledContent("All AI this month", value: AISpend.format(spendMonth == AISpend.currentMonth() ? spentThisMonth : 0))
            } header: {
                Text("Spend")
            } footer: {
                Text("Checks count the ones that finished, at the cost the proxy reported. All AI adds runs that failed partway and every other AI action. The average uses the last \(RealityCheckCost.averageWindow) finished checks and is what the Reality Check button quotes.")
            }

            Section {
                LabeledContent("Ideas", value: "\(liveCount)")
                ForEach(Track.allCases) { track in
                    LabeledContent("  \(track.displayName)", value: "\(TrackCounts.count(track, in: ideas))")
                }
                LabeledContent("Archived", value: "\(archivedCount)")
                LabeledContent("Projects", value: "\(projects.count) · \(projects.filter { $0.status == .active }.count) active")
                if let report = ProjectCleanup.lastReport() {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project cleanup · \(report.ranAt.formatted(date: .abbreviated, time: .shortened))").forgeLabelSmall()
                        Text(report.line).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
            } header: {
                Text("Ideas")
            } footer: {
                Text("Counts are by track, the same as the Ideas tab and Home's pipeline. The cleanup ran once at launch: one project per idea.")
            }

            Section("About") {
                LabeledContent("Version", value: Self.versionString)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ForgeColor.canvas)
        .navigationTitle("Settings")
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
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(try! .forge(inMemory: true))
}
