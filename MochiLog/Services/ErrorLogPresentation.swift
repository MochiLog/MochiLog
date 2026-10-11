import Foundation

struct ErrorLogDay: Identifiable {
  let date: Date
  let entries: [ErrorLogEntry]
  var id: Date { date }
}

enum ErrorLogPresentation {
  static func days(_ entries: [ErrorLogEntry], query: String = "",
    calendar: Calendar = .autoupdatingCurrent) -> [ErrorLogDay] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let filtered = entries.filter { query.isEmpty || $0.message.localizedCaseInsensitiveContains(query) }
    let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.timestamp) }
    return grouped.keys.sorted(by: >).map { day in
      ErrorLogDay(date: day, entries: grouped[day]!.sorted {
        $0.timestamp == $1.timestamp ? $0.id < $1.id : $0.timestamp > $1.timestamp
      })
    }
  }
}
