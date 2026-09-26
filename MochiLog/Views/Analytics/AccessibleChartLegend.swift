import SwiftUI

/// Keep Chart's color keys stable while showing localized device names to the user.
struct AccessibleChartLegend: View {
  let names: [String]
  let colors: [Color]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(names.enumerated()), id: \.element) { index, name in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(systemName: "circle.fill")
            .font(.system(size: 10))
            .foregroundStyle(colors[index])
            .accessibilityHidden(true)
          Text(DeviceLibrary.localizedName(for: name))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
