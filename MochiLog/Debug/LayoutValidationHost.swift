#if DEBUG && targetEnvironment(simulator)
  import SwiftUI

  /// Exercises real screens at hypothetical sizes, not a simulation of Duo hardware or its hinge.
  struct LayoutValidationHost: View {
    @State private var mode = 0
    private var size: CGSize {
      switch mode {
      case 1: return CGSize(width: 390, height: 844)
      case 2: return CGSize(width: 980, height: 700)
      default: return CGSize(width: 800, height: 1120)  // User-supplied 1:1.4 aspect ratio.
      }
    }

    var body: some View {
      VStack(spacing: 8) {
        HStack {
          ForEach(Array(["Wide", "Compact", "Landscape"].enumerated()), id: \.offset) {
            index, label in
            Button(label) { mode = index }
              .accessibilityIdentifier("layout.mode.\(index)")
          }
        }
        .buttonStyle(.bordered)
        MochiLogRootView()
          .environment(\.horizontalSizeClass, mode == 1 ? .compact : .regular)
          .environment(\.verticalSizeClass, .regular)
          .frame(width: size.width, height: size.height)
          .clipped()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }
#endif
