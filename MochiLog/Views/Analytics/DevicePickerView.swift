import SwiftUI

struct DevicePickerView: View {
  let deviceNames: [String]
  @Binding var selectedDevice: String?

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var isShowingDevicePicker: Bool = false
  @State private var deviceSearchQuery: String = ""
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      let layout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
      layout {
        VStack(alignment: .leading, spacing: 4) {
          Text(L10n.string("select_a_device", table: "Analytics"))
            .font(.headline)
            .foregroundStyle(.secondary)

          Text(L10n.string("select_a_device_description", table: "Analytics"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Button {
          deviceSearchQuery = ""
          isShowingDevicePicker = true
        } label: {
          HStack(spacing: 8) {
            Text(selectedDevice ?? L10n.string("all_devices", table: "Common"))
              .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(appSettings.accentColor.color.opacity(0.08), in: Capsule())
        }
        .accessibilityLabel(Text(L10n.string("select_a_device", table: "Analytics")))
        .frame(minWidth: 140)
        .sheet(isPresented: $isShowingDevicePicker) {
          NavigationStack {
            List {
              Button {
                selectedDevice = nil
                isShowingDevicePicker = false
              } label: {
                HStack {
                  Text(L10n.string("all_devices", table: "Common"))
                    .foregroundStyle(appSettings.accentColor.color)
                  Spacer()
                  if selectedDevice == nil {
                    Image(systemName: "checkmark")
                      .foregroundStyle(appSettings.accentColor.color)
                  }
                }
              }

              ForEach(
                deviceNames.filter {
                  deviceSearchQuery.isEmpty
                    ? true : $0.localizedCaseInsensitiveContains(deviceSearchQuery)
                }, id: \.self
              ) { device in
                Button {
                  selectedDevice = device
                  isShowingDevicePicker = false
                } label: {
                  HStack {
                    Text(DeviceLibrary.localizedName(for: device))
                    Spacer()
                    if selectedDevice == device {
                      Image(systemName: "checkmark")
                        .foregroundStyle(appSettings.accentColor.color)
                    }
                  }
                }
                .foregroundStyle(.primary)
              }
            }
            .searchable(text: $deviceSearchQuery)
            .navigationTitle(Text(L10n.string("select_a_device", table: "Analytics")))
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string("cancel", table: "Common")) {
                  isShowingDevicePicker = false
                }
                .tint(.primary)
              }
            }
          }
        }
      }
    }
    .padding(20)
    .mochiCard()
  }
}

// MARK: - デバイスチップ
struct DeviceChip: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    Button(action: action) {
      Text(DeviceLibrary.localizedName(for: name))
        .font(.subheadline)
        .fontWeight(isSelected ? .semibold : .regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          isSelected
            ? appSettings.accentColor.color.opacity(0.2)
            : Color(.systemGray5)
        )
        .foregroundStyle(isSelected ? appSettings.accentColor.color : .primary)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(isSelected ? appSettings.accentColor.color : Color.clear, lineWidth: 1.5)
        )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  DevicePickerView(deviceNames: ["iPhone A", "iPad B"], selectedDevice: .constant(nil))
}
