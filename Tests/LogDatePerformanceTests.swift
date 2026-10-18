import Foundation

@main
struct LogDatePerformanceTests {
  static func main() {
    let inputs = [
      "2026-09-08T03:04:05.123Z", "2026-09-08T03:04:05Z", "2026-09-08 12:04:05.12 +0900",
      "2026-09-08 12:04:05 +0900",
    ]
    let expected = inputs.map { LogDateParser.parse($0)! }
    precondition(abs(expected[0].timeIntervalSince(expected[1]) - 0.123) < 0.001)
    precondition(expected[1] == expected[3])
    precondition(LogDateParser.parse("not a date") == nil)
    let start = Date()
    for index in 0..<3000 {
      let slot = index % inputs.count
      precondition(LogDateParser.parse(inputs[slot]) == expected[slot])
    }
    print(String(format: "3000 mixed date parses: %.3f seconds", Date().timeIntervalSince(start)))
    DispatchQueue.concurrentPerform(iterations: 1000) { index in
      let slot = index % inputs.count
      precondition(LogDateParser.parse(inputs[slot]) == expected[slot])
    }
    print(
      "PASS: fractional seconds, time zones, legacy dates, invalid dates and concurrent parsing")
  }
}
