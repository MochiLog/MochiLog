import Foundation

struct BatteryRecord {
  var id: UUID
  var logDate: Date
  var deviceName: String
}

func parse(dict: [String: Any]) -> BatteryRecord? {
  guard let id = dict["recordID"] as? UUID,
    let logDate = dict["logDate"] as? Date,
    let deviceName = dict["deviceName"] as? String
  else {
    return nil
  }
  return BatteryRecord(id: id, logDate: logDate, deviceName: deviceName)
}
