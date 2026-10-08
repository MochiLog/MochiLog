import Foundation

enum CloudSharingCapability {
  /// An existing pairing may be paused before its first normal response from
  /// an updated PC. Discover support independently of the daily receive cycle.
  static func shouldProbe(advertised: Bool, secureRequired: Bool?, unsupported: Bool) -> Bool {
    advertised || (secureRequired != false && !unsupported)
  }
}
