import SwiftUI

private struct OptionalShadow: ViewModifier {
  @ObservedObject private var rendering = RenderingPreferences.shared
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  let color: Color
  let radius: CGFloat
  let x: CGFloat
  let y: CGFloat
  @ViewBuilder func body(content: Content) -> some View {
    if rendering.reduced || reduceTransparency {
      content
    } else {
      content.shadow(color: color, radius: radius, x: x, y: y)
    }
  }
}

private struct ChartRendering: ViewModifier {
  @ObservedObject private var rendering = RenderingPreferences.shared
  @ViewBuilder func body(content: Content) -> some View {
    if rendering.reduced { content } else { content.drawingGroup() }
  }
}

private struct LoadingSurface: ViewModifier {
  @ObservedObject private var rendering = RenderingPreferences.shared
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  let radius: CGFloat
  func body(content: Content) -> some View {
    content.background(
      rendering.reduced || reduceTransparency
        ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
        : AnyShapeStyle(.ultraThinMaterial),
      in: RoundedRectangle(cornerRadius: radius))
  }
}

extension View {
  func mochiShadow(
    color: Color = .black.opacity(0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0
  ) -> some View {
    modifier(OptionalShadow(color: color, radius: radius, x: x, y: y))
  }
  func mochiChartRendering() -> some View { modifier(ChartRendering()) }
  func mochiLoadingSurface(cornerRadius: CGFloat = 16) -> some View {
    modifier(LoadingSurface(radius: cornerRadius))
  }
}

struct RenderingSettingsRow: View {
  @ObservedObject private var rendering = RenderingPreferences.shared
  var body: some View {
    Picker(selection: $rendering.mode) {
      ForEach(RenderingPreferences.Mode.allCases) { mode in
        Text(L10n.string(String.LocalizationValue("rendering_" + mode.rawValue), table: "Settings"))
          .tag(mode)
      }
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text(L10n.string("rendering_title", table: "Settings"))
        Text(L10n.string("rendering_description", table: "Settings"))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .pickerStyle(.menu)
    .accessibilityIdentifier("settings.rendering")
  }
}
