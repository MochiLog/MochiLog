import SwiftUI
import UIKit

/// 共通のレコードリストビュー
/// サンプルデータと実データで同じレイアウトを使用するための共通コンポーネント
struct RecordListView<Header: View>: View {
  let records: [BatteryRecord]
  private let recordsByDevice: [String: [BatteryRecord]]
  let onRecordTap: ((BatteryRecord) -> Void)?
  let onRecordDelete: ((BatteryRecord) -> Void)?
  let showContextMenu: Bool
  let header: Header

  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var collapsedSections: Set<String> = []
  @State private var allowSectionAnimation = false

  // MARK: - ページネーション用の状態
  /// 各デバイスの表示件数（初期値: 50件）
  @State private var displayLimits: [String: Int] = [:]
  /// 1デバイスあたりの初期表示件数
  private let initialDisplayLimit = 50
  /// 「もっと読み込む」で追加する件数
  private let loadMoreCount = 50

  /// recordsから直接デバイスセクションを計算
  private var cachedSections: [DeviceSection] {
    // デバイス名を抽出（重複排除）
    let deviceNames = Array(recordsByDevice.keys)

    // AppSettings.deviceSortOrderでソート
    let sortedNames: [String]
    if appSettings.deviceSortOrder.isEmpty {
      sortedNames = deviceNames.sorted()
    } else {
      var ordered: [String] = []
      var remaining = Set(deviceNames)

      for name in appSettings.deviceSortOrder {
        if remaining.contains(name) {
          ordered.append(name)
          remaining.remove(name)
        }
      }
      ordered.append(contentsOf: remaining.sorted())
      sortedNames = ordered
    }

    return sortedNames.map {
      DeviceSection(id: $0, displayName: DeviceLibrary.localizedName(for: $0), recordIDs: [])
    }
  }

  init(
    records: [BatteryRecord],
    onRecordTap: ((BatteryRecord) -> Void)? = nil,
    onRecordDelete: ((BatteryRecord) -> Void)? = nil,
    showContextMenu: Bool = true,
    @ViewBuilder header: () -> Header = { EmptyView() }
  ) {
    self.records = records
    self.recordsByDevice = Dictionary(grouping: records, by: \.deviceName)
    self.onRecordTap = onRecordTap
    self.onRecordDelete = onRecordDelete
    self.showContextMenu = showContextMenu
    self.header = header()
  }

  var body: some View {
    ZStack {
      // コンテンツ表示
      Group {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
          iPadGridLayout
        } else if UIDevice.current.userInterfaceIdiom == .pad {
          iPhoneLayout
        } else {
          phoneLogList
        }
      }
      // スクロール中の不要なアニメーションを抑制
      .transaction { transaction in
        if !allowSectionAnimation {
          transaction.animation = nil
        }
      }
    }
  }

  /// セクションIDから表示するレコードを取得するヘルパー（ページネーション対応）
  private func recordsForSection(_ section: DeviceSection) -> [BatteryRecord] {
    // recordsから直接フィルタ
    let filtered = recordsByDevice[section.id] ?? []
    // 表示件数制限を適用
    let limit = displayLimits[section.id] ?? initialDisplayLimit
    return Array(filtered.prefix(limit))
  }

  /// セクションの全レコード数を取得
  private func totalRecordsForSection(_ section: DeviceSection) -> Int {
    return recordsByDevice[section.id]?.count ?? 0
  }

  /// 「もっと読み込む」ボタンを表示すべきか
  private func hasMoreRecords(_ section: DeviceSection) -> Bool {
    let limit = displayLimits[section.id] ?? initialDisplayLimit
    let total = totalRecordsForSection(section)
    return limit < total
  }

  /// 表示件数を増やす
  private func loadMoreRecords(for section: DeviceSection) {
    let currentLimit = displayLimits[section.id] ?? initialDisplayLimit
    displayLimits[section.id] = currentLimit + loadMoreCount
  }

  // MARK: - iPad レイアウト（複数列表示）
  private var iPadGridLayout: some View {
    GeometryReader { geometry in
      ScrollView {
        header
        .frame(maxWidth: 1200)
        .padding(.horizontal, 24)
        .padding(.top, 12)

        let availableWidth = min(geometry.size.width, 1248) - 48
        let minSectionWidth: CGFloat = 340
        let maxColumns = max(1, Int((availableWidth + 24) / (minSectionWidth + 24)))
        let sections = cachedSections
        let columnsCount = min(sections.count, maxColumns)

        // LazyVGridは「行内の最大高さに全セルを揃える」ため、
        // セルの高さが異なると空白が発生する。
        // HStack(alignment: .top) を使うことで各カラムが完全独立し、
        // 互いの高さに引っ張られなくなる。
        HStack(alignment: .top, spacing: 24) {
          ForEach(0..<columnsCount, id: \.self) { columnIndex in
            // カラムに属するセクションを振り分け（2列なら偶数/奇数インデックス）
            let columnSections = sections.indices
              .filter { $0 % columnsCount == columnIndex }
              .map { sections[$0] }
            VStack(alignment: .leading, spacing: 24) {
              ForEach(columnSections, id: \.id) { section in
                let sectionRecords = recordsForSection(section)
                VStack(alignment: .leading, spacing: 16) {
                  // カスタムヘッダーでリッチなセクション表示
                  Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                      allowSectionAnimation = true
                      if collapsedSections.contains(section.id) {
                        collapsedSections.remove(section.id)
                      } else {
                        collapsedSections.insert(section.id)
                      }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                      allowSectionAnimation = false
                    }
                  } label: {
                    HStack(spacing: 12) {
                      let splitName = splitDeviceName(section.displayName)

                      // エレガントなアイコン表示
                      ZStack {
                        Circle()
                          .fill(appSettings.accentColor.color.opacity(0.12))
                          .frame(width: 40, height: 40)
                        Image(systemName: splitName.primary.contains("Watch") ? "applewatch" : (splitName.primary.contains("iPad") ? "ipad" : "iphone"))
                          .foregroundStyle(appSettings.accentColor.color)
                          .font(.system(size: 18, weight: .semibold))
                      }

                      VStack(alignment: .leading, spacing: 2) {
                        Text(splitName.primary)
                          .font(.title3)
                          .fontWeight(.bold)
                          .foregroundColor(.primary)
                        if let secondary = splitName.secondary {
                          Text(secondary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                      }

                      Spacer()

                      ZStack {
                        Circle()
                          .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                          .frame(width: 32, height: 32)
                        Image(systemName: "chevron.up")
                          .foregroundStyle(.secondary)
                          .font(.system(size: 14, weight: .bold))
                          .rotationEffect(.degrees(collapsedSections.contains(section.id) ? 180 : 0))
                      }
                    }
                    .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)

                  if !collapsedSections.contains(section.id) {
                    iPadDeviceSectionContent(
                      section: section,
                      sectionRecords: sectionRecords
                    )
                  }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: collapsedSections)
                .padding(20)
                .mochiCard()
                .transition(
                  .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                  ))
              }
            }
            .frame(maxWidth: .infinity)
          }
        }
        .frame(maxWidth: 1200)
        .padding(24)
        .frame(maxWidth: .infinity)
      }
    }
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private var phoneLogList: some View {
    List {
      header
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

      ForEach(cachedSections, id: \.id) { section in
        let sectionRecords = recordsForSection(section)
        Section {
          Button {
            withAnimation(.snappy) {
              allowSectionAnimation = true
              if collapsedSections.contains(section.id) {
                collapsedSections.remove(section.id)
              } else {
                collapsedSections.insert(section.id)
              }
            }
          } label: {
            HStack(spacing: 8) {
              Text(section.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 8)
              Image(systemName: collapsedSections.contains(section.id) ? "chevron.right" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .textCase(nil)
          .accessibilityAddTraits(.isHeader)
          if !collapsedSections.contains(section.id) {
            ForEach(sectionRecords, id: \.id) { record in
              Button {
                onRecordTap?(record)
              } label: {
                RecordRowView(record: record)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("home.record.\(record.id)")
              .listRowInsets(EdgeInsets(top: 2, leading: 24, bottom: 2, trailing: 24))
            }
            .onDelete { offsets in
              if let onDelete = onRecordDelete {
                offsets.map { sectionRecords[$0] }.forEach(onDelete)
              }
            }
            if hasMoreRecords(section) {
              Button { loadMoreRecords(for: section) } label: {
                HStack {
                  Text(L10n.string("load_more", table: "Home"))
                  Spacer()
                  Text("\(sectionRecords.count) / \(totalRecordsForSection(section))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .font(.subheadline)
                .padding(.vertical, 6)
              }
            }
          }

        }
      }
    }
    .listStyle(.insetGrouped)
    .task(id: collapsedSections) {
      // Restart the delay on another tap so rapid toggles keep animating.
      do {
        try await Task.sleep(for: .milliseconds(500))
        allowSectionAnimation = false
      } catch { }
    }
  }

  // MARK: - iPad compact layout
  private var iPhoneLayout: some View {
    List {
      header
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

      ForEach(cachedSections, id: \.id) { section in
        let sectionRecords = recordsForSection(section)
        Section {
          DisclosureGroup(
            isExpanded: Binding(
              get: { !collapsedSections.contains(section.id) },
              set: { isExpanded in
                withAnimation(.snappy) {
                  allowSectionAnimation = true
                  if isExpanded {
                    collapsedSections.remove(section.id)
                  } else {
                    collapsedSections.insert(section.id)
                  }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                  allowSectionAnimation = false
                }
              }
            )
          ) {
            ForEach(sectionRecords, id: \.id) { record in
              Button {
                onRecordTap?(record)
              } label: {
                RecordRowView(record: record)
                  .contentShape(Rectangle())
              }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.record.\(record.id)")
                .transition(
                  .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                  ))
            }
            .onDelete { offsets in
              if let onDelete = onRecordDelete {
                let items = offsets.map { sectionRecords[$0] }
                items.forEach { onDelete($0) }
              }
            }

            // もっと読み込むボタン
            if hasMoreRecords(section) {
              Button {
                withAnimation(.snappy) {
                  loadMoreRecords(for: section)
                }
              } label: {
                HStack {
                  Spacer()
                  Text(L10n.string("load_more", table: "Home"))
                    .font(.subheadline)
                  Text("(\(sectionRecords.count)/\(totalRecordsForSection(section)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                }
                .padding(.vertical, 8)
              }
              .buttonStyle(.borderless)
            }
          } label: {
            Label {
              Text(section.displayName).font(.headline)
            } icon: {
              Image(systemName: section.displayName.contains("Watch") ? "applewatch"
                : section.displayName.contains("iPad") ? "ipad" : "iphone")
                .foregroundStyle(appSettings.accentColor.color)
            }
            .padding(.vertical, 6)
            .foregroundColor(.primary)
          }
          .animation(.snappy, value: collapsedSections)
        }
        .transition(
          .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
          ))
      }
    }
  }

  // MARK: - iPadレイアウト用ヘルパービュー
  @ViewBuilder
  private func iPadDeviceSectionContent(
    section: DeviceSection,
    sectionRecords: [BatteryRecord]
  ) -> some View {
    // DisclosureGroupを廃止したため、LazyVGridが自然なレイアウトで動作します
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 12) {
      ForEach(sectionRecords, id: \.id) { record in
        iPadRecordCard(record: record, section: section)
      }
    }
    .padding(.top, 8)

    // もっと読み込むボタン
    if hasMoreRecords(section) {
      Button {
        withAnimation(.snappy) {
          loadMoreRecords(for: section)
        }
      } label: {
        HStack {
          Spacer()
          Text(L10n.string("load_more", table: "Home"))
            .font(.subheadline)
          Text("(\(sectionRecords.count)/\(totalRecordsForSection(section)))")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .padding(.top, 8)
    }
  }

  /// iPad用個別レコードカード
  @ViewBuilder
  private func iPadRecordCard(record: BatteryRecord, section: DeviceSection) -> some View {
    Button {
      onRecordTap?(record)
    } label: {
      ModerniPadRecordCard(record: record)
        .padding(16)
        .background(
          Color(uiColor: .tertiarySystemGroupedBackground)
            .mochiShadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color(uiColor: .separator).opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("home.record.\(record.id)")
    .contextMenu {
      if showContextMenu, let onDelete = onRecordDelete {
        Button(role: .destructive) {
          onDelete(record)
        } label: {
          Label {
            Text(L10n.string("delete", table: "Common"))
          } icon: {
            Image(
              uiImage: UIImage(systemName: "trash")?
                .withTintColor(.red, renderingMode: .alwaysOriginal)
                ?? UIImage())
          }
        }
      }
    }
    .animation(.snappy, value: collapsedSections)
  }

  // MARK: - デバイス名表示ヘルパー（iPad用）
  /// デバイス名を種類と詳細に分割して表示を綺麗にする
  /// 例: "iPhone 16 Pro Max" → ("iPhone 16", "Pro Max")
  /// 例: "Apple Watch Ultra 2" → ("Apple Watch", "Ultra 2")
  private func splitDeviceName(_ name: String) -> (primary: String, secondary: String?) {
    // Apple Watch の場合：「Apple Watch」の後ろで分割
    if name.hasPrefix("Apple Watch") {
      let rest = String(name.dropFirst("Apple Watch".count)).trimmingCharacters(in: .whitespaces)
      return rest.isEmpty ? (name, nil) : ("Apple Watch", rest)
    }
    // iPhone / iPad の場合：ブランド名 + 最初の識別子 / 残りで分割
    for prefix in ["iPhone", "iPad"] {
      guard name.hasPrefix(prefix) else { continue }
      let rest = String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      let words = rest.split(separator: " ", maxSplits: .max, omittingEmptySubsequences: true)
      guard words.count >= 2 else { return (name, nil) }
      let primary = "\(prefix) \(words[0])"
      let secondary = words.dropFirst().joined(separator: " ")
      return (primary, secondary)
    }
    return (name, nil)
  }

  // MARK: - デバイスセクション構造体
  private struct DeviceSection: Identifiable, Equatable {
    let id: String
    let displayName: String
    let recordIDs: [String]

    static func == (lhs: DeviceSection, rhs: DeviceSection) -> Bool {
      lhs.id == rhs.id && lhs.recordIDs == rhs.recordIDs
    }
  }
}

// MARK: - Modern iPad Record Card
private struct ModerniPadRecordCard: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      // 左側: 日付と基本情報
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "calendar")
            .foregroundStyle(appSettings.accentColor.color)
            .font(.caption)
          Text(record.logDate, style: .date)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
        }

        VStack(alignment: .leading, spacing: 5) {
          Label(
            String(format: L10n.string("cycle_count_format", table: "Analytics"), record.cycleCount),
            systemImage: "arrow.triangle.2.circlepath"
          )
          .font(.caption)
          .foregroundStyle(Color.secondary)

          Label("\(record.nominalCapacity) mAh", systemImage: "battery.100")
            .font(.caption)
            .foregroundStyle(Color.secondary)
        }

        Text(record.cachedDiagnostic)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      // 右側: 健康度リング
      let health = appSettings.analysisDataSource == .nominal ? record.nominalHealthPercent : record.healthPercent

      ZStack {
        Circle()
          .stroke(Color(uiColor: .systemGray5), lineWidth: 5)
          .frame(width: 52, height: 52)

        Circle()
          .trim(from: 0, to: CGFloat(min(max(health, 0), 100)) / 100.0)
          .stroke(
            healthColor(health),
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 52, height: 52)

        Text("\(String(format: "%.0f", health))%")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundStyle(healthColor(health))
      }
    }
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}
