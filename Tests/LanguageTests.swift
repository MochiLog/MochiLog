import Foundation

@main
struct LanguageTests {
  @MainActor
  static func main() {
    let cases: [(String, String)] = [
      ("ja-JP", "ja"), ("en-GB", "en"), ("zh-CN", "zh-Hans"),
      ("zh-TW", "zh-Hant"), ("zh-HK", "zh-Hant"), ("ko-KR", "ko"),
      ("es-MX", "es"), ("fr-CA", "fr"), ("de-AT", "de"),
    ]
    for (device, expected) in cases {
      assert(
        L10n.resolve(selection: "system", preferredLanguages: [device]) == expected,
        "Device language \(device) must resolve to \(expected)")
    }
    assert(L10n.resolve(selection: nil, preferredLanguages: ["xx-XX"]) == "en")
    assert(L10n.resolve(selection: "system", preferredLanguages: ["it-IT", "fr-FR"]) == "fr")
    assert(L10n.resolve(selection: "de", preferredLanguages: ["ja-JP"]) == "de")
    assert(Set(AppLanguage.allCases.map(\.rawValue)) == Set(["system"] + L10n.supportedLanguages))
    print(
      "PASS: device language matching, unsupported language fallback, explicit override, all supported languages"
    )
  }
}
