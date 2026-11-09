import SwiftUI
import ForgeCore

/// Decision 0039: "What did they give?" as full-width rows with words that fit
/// at any text size, never truncated chips.
struct RungChoices: View {
    let options: [Int]
    let selected: Int
    var onSelect: (Int) -> Void

    static func detail(_ rung: Int) -> String {
        switch rung {
        case 5: "Used it again, renewed, or asked for more"
        case 4: "Paid, or put money down"
        case 3: "Talked it through with you, or signed up"
        default: "Nothing yet: no time, money or return"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { r in
                let on = r == selected
                Button { onSelect(r) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: on ? "largecircle.fill.circle" : "circle")
                            .font(.title3).foregroundStyle(on ? ForgeColor.ember : ForgeColor.inkSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(RungInference.label(r)).font(.system(.body, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                            Text(Self.detail(r)).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? ForgeColor.ember : ForgeColor.line, lineWidth: on ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(RungInference.label(r)): \(Self.detail(r))")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
