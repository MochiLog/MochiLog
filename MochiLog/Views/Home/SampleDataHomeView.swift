import SwiftUI

// MARK: - サンプルデータホームビュー
/// データがない時にサンプルデータを表示するビュー
/// 共通のRecordListViewを使用してコード重複を排除
struct SampleDataHomeView: View {
  @Binding var showingSampleData: Bool
  /// レコードタップ時のコールバック
  let onRecordTap: (BatteryRecord) -> Void
  let openFilePicker: () -> Void
  @StateObject private var appSettings = AppSettings.shared
  @State private var showingReorderSheet = false

  private let sampleRecords = SampleDataProvider.generateSampleRecords().sorted(by: {
    $0.logDate > $1.logDate
  })

  var body: some View {
    // 共通のRecordListViewを使用
    RecordListView(
      records: sampleRecords,
      onRecordTap: { record in
        onRecordTap(record)
      },
      onRecordDelete: nil,  // サンプルデータは削除不可
      showContextMenu: false
    ) {
      // サンプルデータバナー（リストと一緒にスクロール）
      SampleDataBanner(
        onClose: {
          withAnimation {
            showingSampleData = false
          }
        },
        onAddData: openFilePicker
      )
    }
  }
}

// MARK: - サンプルデータバナー
struct SampleDataBanner: View {
  let onClose: () -> Void
  let onAddData: () -> Void
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 12) {
          bannerText
          HStack(spacing: 12) {
            addButton
            Spacer()
            closeButton
          }
        }
      } else {
        HStack(spacing: 12) {
          Image(systemName: "eye.fill")
            .foregroundStyle(appSettings.accentColor.color)
          bannerText
          Spacer()
          addButton
          closeButton
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .mochiLoadingSurface()
    .accessibilityIdentifier("home.sampleBanner")
  }

  private var bannerText: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(L10n.string("sample_data_viewing", table: "Home"))
        .font(.subheadline)
        .fontWeight(.medium)
      Text(L10n.string("sample_data_hint", table: "Home"))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var addButton: some View {
    Button(L10n.string("add_data", table: "Home"), action: onAddData)
      .font(.caption)
      .buttonStyle(.borderedProminent)
      .fixedSize(horizontal: true, vertical: false)
  }

  private var closeButton: some View {
    Button(action: onClose) {
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  SampleDataHomeView(
    showingSampleData: .constant(true), onRecordTap: { _ in }, openFilePicker: {})
}
