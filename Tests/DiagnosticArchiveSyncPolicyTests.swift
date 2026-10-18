import Foundation

@main struct DiagnosticArchiveSyncPolicyTests {
  static func main() {
    // A large history on PC A stays pending throughout this simulation. PC B
    // must still get a chance to supply its pending battery log promptly.
    var current = 0
    var rounds = 0
    var serviced: Set<Int> = []
    for _ in 0..<16 {
      serviced.insert(current)
      rounds += 1
      if DiagnosticArchiveSyncPolicy.shouldRotate(completedRounds: rounds, pairedComputers: 2) {
        current = (current + 1) % 2
        rounds = 0
      }
    }
    precondition(serviced == [0, 1])
    precondition(current == 0 && rounds == 0)
    precondition(
      !DiagnosticArchiveSyncPolicy.shouldRotate(completedRounds: 100, pairedComputers: 1))
    precondition(DiagnosticArchiveSyncPolicy.continuationDelay(completedRounds: 25) == 10)
    precondition(DiagnosticArchiveSyncPolicy.continuationDelay(completedRounds: 1) > 0)
    print(
      "PASS: pending diagnostic history yields to another PC; single-PC catch-up remains bounded")
  }
}
