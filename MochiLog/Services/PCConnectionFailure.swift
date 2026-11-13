import Foundation
import Network

/// Structured technical detail stays in diagnostics. UI uses only messageKey.
nonisolated struct PCConnectionFailure: Error, CustomNSError {
  enum Kind: String, CaseIterable {
    case connectTimeout, responseTimeout, incompleteResponse, networkDenied, networkUnavailable
    case networkPolicyDenied, connectionRefused, connectionLost, unverifiedPeer, pairingRejected,
      pinFormat, storage
    case wrongDevice, portBusy, invalidAddress, settingsStorage, invalidData, unknown
  }
  let kind: Kind
  let phase: String
  let originDomain: String
  let originCode: Int
  let receivedBytes: Int

  static var errorDomain: String { "MochiLog.PCConnectionFailure" }
  var errorCode: Int { originCode }
  var messageKey: String { "mt_failure_" + kind.rawValue }
  var diagnosticCode: String {
    switch kind {
    case .connectTimeout: "ML-PC-101"
    case .responseTimeout: "ML-PC-102"
    case .incompleteResponse: "ML-PC-103"
    case .networkDenied: "ML-PC-104"
    case .networkUnavailable: "ML-PC-105"
    case .networkPolicyDenied: "ML-PC-114"
    case .connectionRefused: "ML-PC-106"
    case .connectionLost: "ML-PC-107"
    case .unverifiedPeer: "ML-PC-108"
    case .pairingRejected: "ML-PC-109"
    case .pinFormat: "ML-PC-110"
    case .storage: "ML-PC-111"
    case .wrongDevice: "ML-PC-112"
    case .portBusy: "ML-PC-113"
    case .invalidAddress: "ML-PC-115"
    case .settingsStorage: "ML-PC-116"
    case .invalidData: "ML-PC-117"
    case .unknown: "ML-PC-199"
    }
  }
  var diagnosticDescription: String {
    "diagnostic=\(diagnosticCode), kind=\(kind.rawValue), phase=\(phase), domain=\(originDomain), code=\(originCode), receivedBytes=\(receivedBytes)"
  }
  init(_ kind: Kind, phase: String, error: Error? = nil, receivedBytes: Int = 0) {
    let value = error.map(Self.systemError)
    self.kind = kind
    self.phase = String(phase.prefix(64))
    originDomain = String(
      (value?.domain ?? "MochiLog").filter {
        $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0))
      }.prefix(80))
    originCode = value?.code ?? 0
    self.receivedBytes = receivedBytes
  }
  static func timeout(phase: String, bytes: Int, denied: Bool) -> PCConnectionFailure {
    let kind: Kind =
      denied
      ? .networkDenied
      : (bytes > 0
        ? .incompleteResponse
        : (phase == "waiting-for-response" || phase == "waiting-first-byte"
          ? .responseTimeout : .connectTimeout))
    return .init(kind, phase: phase, error: URLError(.timedOut), receivedBytes: bytes)
  }
  static func systemError(_ error: Error) -> NSError {
    if let network = error as? NWError {
      switch network {
      case .posix(let code): return NSError(domain: NSPOSIXErrorDomain, code: Int(code.rawValue))
      case .dns(let code): return NSError(domain: "DNSServiceError", code: Int(code))
      default: break
      }
    }
    return error as NSError
  }

  static func classify(_ error: Error, phase: String, denied: Bool = false, receivedBytes: Int = 0)
    -> PCConnectionFailure
  {
    if let failure = error as? PCConnectionFailure { return failure }
    let value = systemError(error)
    if denied {
      return .init(.networkDenied, phase: phase, error: error, receivedBytes: receivedBytes)
    }
    if value.domain == NSURLErrorDomain {
      if value.code == URLError.timedOut.rawValue {
        return .init(
          phase == "receiving" || receivedBytes > 0
            ? .incompleteResponse
            : (phase == "waiting-for-response" || phase == "waiting-first-byte"
              ? .responseTimeout : .connectTimeout), phase: phase, error: error,
          receivedBytes: receivedBytes)
      }
      if value.code == URLError.notConnectedToInternet.rawValue {
        return .init(.networkUnavailable, phase: phase, error: error, receivedBytes: receivedBytes)
      }
      if value.code == URLError.networkConnectionLost.rawValue {
        return .init(.connectionLost, phase: phase, error: error, receivedBytes: receivedBytes)
      }
    }
    if value.domain == "DNSServiceError", value.code == -65570 {
      return .init(.networkPolicyDenied, phase: phase, error: error, receivedBytes: receivedBytes)
    }
    if value.domain == NSPOSIXErrorDomain {
      switch value.code {
      case 1, 13:
        return .init(.networkPolicyDenied, phase: phase, error: error, receivedBytes: receivedBytes)
      case 61:
        return .init(.connectionRefused, phase: phase, error: error, receivedBytes: receivedBytes)
      case 48: return .init(.portBusy, phase: phase, error: error, receivedBytes: receivedBytes)
      case 50, 51, 64, 65:
        return .init(.networkUnavailable, phase: phase, error: error, receivedBytes: receivedBytes)
      case 32, 54, 57:
        return .init(.connectionLost, phase: phase, error: error, receivedBytes: receivedBytes)
      case 60:
        return .init(
          phase == "receiving" || receivedBytes > 0
            ? .incompleteResponse
            : (phase == "waiting-for-response" || phase == "waiting-first-byte"
              ? .responseTimeout : .connectTimeout), phase: phase, error: error,
          receivedBytes: receivedBytes)
      default: break
      }
    }
    return .init(.unknown, phase: phase, error: error, receivedBytes: receivedBytes)
  }
}
