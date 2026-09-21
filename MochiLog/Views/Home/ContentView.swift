import SwiftUI

struct ContentView: View {
  var body: some View {
    MainTabView()
  }
}


/// Shared surfaces keep charts, summaries and settings visually consistent.
struct MochiCardSurface: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .background(Color(uiColor: .secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.045), lineWidth: 1)
      }
      .mochiShadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.025), radius: 12, y: 5)
  }
}

extension View {
  func mochiCard() -> some View { modifier(MochiCardSurface()) }
}
