import SwiftUI
import ForgeCore

/// Decision 0046: the owner's key, kept in the keychain of the owner's own
/// phone. No build carries it; it is typed in once (a long press on Version
/// in Settings). Without it there is no Spend row and nothing to find.
enum OwnerAccess {
    private static let box = KeychainBox(service: "app.hunch.owner")
    private static let account = "secret"

    static var key: String? {
        let k = box.get(account)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return k.isEmpty ? nil : k
    }

    static var hasKey: Bool { key != nil }

    static func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { remove() } else { box.set(trimmed, for: account) }
    }

    static func remove() { box.remove(account) }
}

extension ProxyAIClient {
    /// GET /api/spend with the owner's key. What the proxy has spent today,
    /// this week and this month, from actual token usage.
    func ownerSpend(key: String) async throws -> OwnerSpend {
        var request = URLRequest(url: baseURL.appending(path: "api/spend"))
        request.timeoutInterval = 20
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse("no HTTP response") }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw AIError.notConfigured
        default: throw AIError.server(status: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(OwnerSpend.self, from: data)
        } catch {
            throw AIError.invalidResponse(String(describing: error))
        }
    }
}

/// Settings → Spend, for the owner only: today against the ceiling, then this
/// week and this month. The numbers are the server's, from actual token usage.
struct SpendView: View {
    enum Load: Equatable { case loading, loaded(OwnerSpend), failed(String) }

    @State private var load: Load = .loading

    var body: some View {
        List {
            switch load {
            case .loading:
                Section { HStack(spacing: ForgeSpacing.s) { ProgressView(); Text("Asking the server…").foregroundStyle(ForgeColor.inkSecondary) } }
            case .failed(let message):
                Section {
                    Text(message).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                    Button("Try again") { Task { await refresh() } }
                }
            case .loaded(let spend):
                Section {
                    VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                        Text(spend.todayLine).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                        ProgressView(value: spend.share).tint(spend.state == "open" ? ForgeColor.ink : ForgeColor.ember)
                            .accessibilityLabel("\(Int((spend.share * 100).rounded())) percent of today's ceiling")
                        Text(spend.stateLine).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Checks today", value: OwnerSpend.checksLine(spend.today))
                } header: {
                    Text("Today")
                }
                Section {
                    row("This week", spend.week)
                    row("This month", spend.month)
                } header: {
                    Text("So far")
                } footer: {
                    Text("From what the AI actually used, counted by the server. The week starts on Monday; days roll over at midnight \(spend.timeZone). The benchmark and anything else that calls the AI without going through the server isn't in here.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ForgeColor.canvas)
        .navigationTitle("Spend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh")
            }
        }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func row(_ title: String, _ period: OwnerSpend.Period) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: OwnerSpend.money(period.usd))
            Text(OwnerSpend.checksLine(period)).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func refresh() async {
        guard let key = OwnerAccess.key else { load = .failed("No owner key is saved on this phone."); return }
        guard let client = ProxyAIClient.configured() else { load = .failed("This build has no server address."); return }
        if case .loaded = load {} else { load = .loading }
        do {
            load = .loaded(try await client.ownerSpend(key: key))
        } catch AIError.offline {
            load = .failed("Couldn't reach the server. Check the connection and try again.")
        } catch AIError.notConfigured {
            load = .failed("The server didn't accept this key. Check it against FORGE_OWNER_SECRET on Vercel, then long-press Version in Settings to enter it again.")
        } catch {
            load = .failed("The server answered, but not with the spend numbers. It may not have this update yet.")
        }
    }
}

#Preview("Spend, past 70%") {
    NavigationStack {
        List {
            Section("Today") { Text("$2.25 of $3.00 today") }
        }
        .navigationTitle("Spend")
    }
    .preferredColorScheme(.dark)
}
