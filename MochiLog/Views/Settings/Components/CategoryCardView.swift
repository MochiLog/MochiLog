import SwiftUI

// MARK: - カテゴリカードビュー
struct CategoryCardView: View {
  let title: String
  let icon: String
  let isSelected: Bool

  init(category: SettingsCategory, isSelected: Bool) {
    self.init(title: category.title, icon: category.icon, isSelected: isSelected)
  }

  init(title: String, icon: String, isSelected: Bool) {
    self.title = title
    self.icon = icon
    self.isSelected = isSelected
  }

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .frame(width: 38, height: 38)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

      Spacer(minLength: 0)
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(
          isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemGroupedBackground))
    )
  }
}
