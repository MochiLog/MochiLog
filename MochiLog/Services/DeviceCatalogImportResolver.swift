import Foundation

enum DeviceCatalogImportResolver {
  /// Retry a previously unknown model after a bounded, shared catalog check.
  /// Existing parsers stay synchronous; network work never blocks their worker queue.
  @MainActor
  static func resolve(
    _ result: LogParser.ParseResult, text: String, validation: Bool, threshold: Double
  ) async -> LogParser.ParseResult {
    guard let identifier = result.detectedIdentifier ?? result.deviceModelCode,
      DeviceLibrary.getDeviceName(for: identifier) == nil
    else { return result }
    _ = await DeviceCatalogUpdater.shared.checkForUnknownModel(identifier)
    guard DeviceLibrary.getDeviceName(for: identifier) != nil else { return result }
    return await parse(text: text, validation: validation, threshold: threshold)
  }

  static func parse(text: String, validation: Bool, threshold: Double) async
    -> LogParser.ParseResult
  {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        continuation.resume(
          returning: LogParser.parse(
            text: text, enableValidation: validation, validationThreshold: threshold))
      }
    }
  }
}
