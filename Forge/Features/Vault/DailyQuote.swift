import SwiftUI
import ForgeCore

/// The quotes setting, stored by raw value so Settings' picker can bind to it.
enum QuotesPreference {
    static let key = "quotes.setting"
    static let dismissedKey = "quotes.dismissedDay"

    static var setting: QuotesSetting {
        QuotesSetting(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .all
    }
}

/// One line at the top of the Idea tab, rotating daily: small italic serif,
/// the attribution in mono beneath, dismissible for the day.
struct DailyQuote: View {
    @AppStorage(QuotesPreference.key) private var settingRaw: String = QuotesSetting.all.rawValue
    @AppStorage(QuotesPreference.dismissedKey) private var dismissedDay: String = ""

    private var setting: QuotesSetting { QuotesSetting(rawValue: settingRaw) ?? .all }
    private var today: String { Quotes.dayKey(.now) }
    private var quote: Quote? { dismissedDay == today ? nil : Quotes.forDay(.now, setting: setting) }

    var body: some View {
        if let quote {
            HStack(alignment: .top, spacing: ForgeSpacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("“\(quote.text)”")
                        .font(Font.custom("Fraunces-Italic", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(ForgeColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(quote.attribution).forgeLabelSmall()
                }
                Spacer(minLength: 0)
                Button { withAnimation(ForgeMotion.fade) { dismissedDay = today } } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss for today")
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
            .accessibilityElement(children: .combine)
        }
    }
}
