import SwiftUI

/// Shared controls with readable date boundaries and full-size touch targets.
struct ChartRangeSelector: View {
  @Binding var selectedRange: RangePreset
  let canMoveNext: Bool
  let canMovePrevious: Bool
  let shiftWindow: (Bool) -> Void
  let startDay: Date
  let endDay: Date
  var identifierPrefix = "chart"

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(
        "\(startDay.formatted(date: .abbreviated, time: .omitted)) – \(endDay.formatted(date: .abbreviated, time: .omitted))"
      )
      .accessibilityIdentifier(identifierPrefix + ".window")
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 8) {
        Picker(L10n.string("chart_range", table: "Analytics"), selection: $selectedRange) {
          ForEach(RangePreset.manualCases) { preset in
            Text(preset.localizedName).tag(preset)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier(identifierPrefix + ".range")
        .frame(minHeight: 44)
        Spacer(minLength: 0)
        Button {
          shiftWindow(true)
        } label: {
          Image(systemName: "chevron.left").frame(width: 44, height: 44)
        }
        .accessibilityLabel(L10n.string("back", table: "Common"))
        .accessibilityIdentifier(identifierPrefix + ".previous")
        .disabled(!canMovePrevious)
        Button {
          shiftWindow(false)
        } label: {
          Image(systemName: "chevron.right").frame(width: 44, height: 44)
        }
        .accessibilityLabel(L10n.string("next", table: "Common"))
        .accessibilityIdentifier(identifierPrefix + ".next")
        .disabled(!canMoveNext)
      }
      .font(.subheadline.weight(.medium))
      .buttonStyle(.borderless)
      .padding(.horizontal, 8)
      .background(
        Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
  }
}
