import SwiftUI

struct ExactDuplicatesReviewView: View {
  @EnvironmentObject private var dataStore: DataStore
  @ObservedObject private var settings = AppSettings.shared
  var onClose: (() -> Void)? = nil

  @State private var selected: Set<ExactRecordPayload> = []
  @State private var showingConfirmation = false
  @State private var showingResult = false
  @State private var resultMessage = ""
  @State private var backupURL: URL?

  private var groups: [ExactDuplicateGroup] {
    ExactDuplicateRecords.groups(in: dataStore.recordsDescending)
  }

  private var selectedExtraCount: Int {
    groups.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.extraCount }
  }

  var body: some View {
    List {
      Section {
        Text(L10n.string("exact_duplicates_explanation", table: "ExactDuplicates"))
          .foregroundStyle(.secondary)
        if groups.isEmpty {
          Label(L10n.string("exact_duplicates_none", table: "ExactDuplicates"), systemImage: "checkmark.circle")
            .foregroundStyle(.green)
        } else {
          Text(String(format: L10n.string("exact_duplicates_found", table: "ExactDuplicates"),
                      groups.count, groups.reduce(0) { $0 + $1.extraCount }))
            .font(.headline)
        }
      }

      if !groups.isEmpty {
        Section {
          Button {
            if selected.count == groups.count {
              selected.removeAll()
            } else {
              selected = Set(groups.map(\.id))
            }
          } label: {
            Text(L10n.string(selected.count == groups.count
              ? "exact_duplicates_deselect_all" : "exact_duplicates_select_all", table: "ExactDuplicates"))
          }

          ForEach(groups) { group in
            Button {
              if !selected.insert(group.id).inserted { selected.remove(group.id) }
            } label: {
              HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected.contains(group.id) ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(selected.contains(group.id) ? settings.accentColor.color : .secondary)
                  .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                  Text(group.representative.localizedDeviceName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                  Text(group.id.logDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
                  Text(String(format: L10n.string("exact_duplicates_values", table: "ExactDuplicates"),
                              group.id.cycleCount, group.id.rawCapacity, group.id.nominalCapacity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: L10n.string("exact_duplicates_copies", table: "ExactDuplicates"),
                            group.records.count))
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("duplicates.group")
          }
        } header: {
          Text(L10n.string("exact_duplicates_title", table: "ExactDuplicates"))
        }

        Section {
          Button(role: .destructive) { showingConfirmation = true } label: {
            Label(String(format: L10n.string("exact_duplicates_remove_selected", table: "ExactDuplicates"),
                         selectedExtraCount), systemImage: "trash")
          }
          .accessibilityIdentifier("duplicates.removeSelected")
          .disabled(selectedExtraCount == 0 || settings.allowDuplicateRecords)
        } footer: {
          Text(L10n.string("exact_duplicates_recheck", table: "ExactDuplicates"))
        }
      }

      if let backupURL {
        Section {
          ShareLink(item: backupURL) {
            Label(L10n.string("exact_duplicates_save_backup", table: "ExactDuplicates"),
                  systemImage: "square.and.arrow.up")
          }
        } footer: {
          Text(L10n.string("exact_duplicates_backup_footer", table: "ExactDuplicates"))
        }
      }
    }
    .navigationTitle(L10n.string("exact_duplicates_title", table: "ExactDuplicates"))
    .toolbar {
      if let onClose {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("close", table: "Common"), action: onClose)
        }
      }
    }
    .alert(L10n.string("exact_duplicates_confirm_title", table: "ExactDuplicates"),
           isPresented: $showingConfirmation) {
      Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
      Button(L10n.string("delete", table: "Common"), role: .destructive) {
        removeSelected()
      }
    } message: {
      Text(String(format: L10n.string("exact_duplicates_confirm_message", table: "ExactDuplicates"),
                  selectedExtraCount))
    }
    .alert(L10n.string("exact_duplicates_title", table: "ExactDuplicates"),
           isPresented: $showingResult) {
      Button(L10n.string("ok", table: "Common"), role: .cancel) {}
    } message: {
      Text(resultMessage)
    }
  }

  private func removeSelected() {
    guard !settings.allowDuplicateRecords else { return }
    do {
      // Keep a recoverable copy of all visible records before any CloudKit deletion.
      dataStore.refreshRecords()
      let currentGroups = ExactDuplicateRecords.groups(in: dataStore.recordsDescending)
      guard currentGroups.contains(where: { selected.contains($0.id) }) else {
        selected.removeAll()
        return
      }
      let yaml = try DataExportService.exportToYAML(records: dataStore.recordsDescending)
      let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let url = directory.appendingPathComponent("MochiLog-before-duplicate-cleanup-\(UUID().uuidString).yaml")
      try yaml.write(to: url, atomically: true, encoding: .utf8)
      backupURL = url

      let removed = try ExactDuplicateRecords.removeSelected(selected, from: dataStore)
      selected.removeAll()
      resultMessage = String(format: L10n.string("exact_duplicates_removed", table: "ExactDuplicates"), removed)
      showingResult = true
    } catch {
      resultMessage = error.localizedDescription
      showingResult = true
    }
  }
}
