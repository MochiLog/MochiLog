import SwiftUI

/// ライセンス情報を表すモデル
struct LicenseInfo: Identifiable {
  let id = UUID()
  let name: String
  let licenseType: String
  let copyright: String
  let licenseText: String
  let fullLicenseText: String?  // 完全版ライセンステキスト（オプション）
  let url: String?
}

/// ライセンス表示画面
struct LicenseView: View {
  @Environment(\.dismiss) private var dismiss

  // MARK: - ライセンス一覧
  private let licenses: [LicenseInfo] = [
    // アプリ本体のライセンス
    LicenseInfo(
      name: "MochiLog",
      licenseType: "GNU General Public License v3.0",
      copyright: "Copyright (C) 2024-2026 Ryuya",
      licenseText: """
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program. If not, see <https://www.gnu.org/licenses/>.

        NOTE: For binaries distributed through the Apple App Store, Apple's
        standard End User License Agreement (EULA) applies in accordance with
        the App Store terms of service.
        """,
      fullLicenseText: Self.loadGPLv3FullText(),
      url: "https://github.com/MochiLog/MochiLog"
    ),
    // ZIPFoundation ライブラリ
    LicenseInfo(
      name: "ZIPFoundation",
      licenseType: "MIT License",
      copyright: "Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)",
      licenseText: """
        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """,
      fullLicenseText: nil,
      url: "https://github.com/weichsel/ZIPFoundation"
    ),
    // Yams ライブラリ
    LicenseInfo(
      name: "Yams",
      licenseType: "MIT License",
      copyright: "Copyright (c) 2016 JP Simard.",
      licenseText: """
        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """,
      fullLicenseText: nil,
      url: "https://github.com/jpsim/Yams"
    ),
  ]

  // MARK: - GPL v3完全版テキストの読み込み
  private static func loadGPLv3FullText() -> String? {
    // プロジェクトルートのLICENSEファイルを読み込む
    if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) {
      return try? String(contentsOf: url, encoding: .utf8)
    }
    return nil
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(licenses) { license in
          NavigationLink {
            LicenseDetailView(license: license)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(license.name)
                .font(.headline)
              Text(license.licenseType)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
          }
        }
      }
      .navigationTitle(L10n.string("licenses", table: "Settings"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("close", table: "Common")) {
            dismiss()
          }
        }
      }
    }
  }
}

/// ライセンス詳細画面
struct LicenseDetailView: View {
  let license: LicenseInfo
  @State private var showingFullLicense = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // ヘッダー
        VStack(alignment: .leading, spacing: 8) {
          Text(license.name)
            .font(.title2)
            .fontWeight(.bold)

          Text(license.licenseType)
            .font(.subheadline)
            .foregroundColor(.secondary)

          Text(license.copyright)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Divider()

        // ライセンス本文
        Text(license.licenseText)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)

        // 完全版ライセンス表示ボタン
        if license.fullLicenseText != nil {
          Button(action: { showingFullLicense = true }) {
            HStack {
              Image(systemName: "doc.text")
              Text(L10n.string("view_full_license", table: "Settings"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
          }
          .buttonStyle(.plain)
        }

        // リンク
        if let urlString = license.url, let url = URL(string: urlString) {
          Divider()

          Link(destination: url) {
            HStack {
              Image(systemName: "link")
              Text(urlString)
                .font(.caption)
            }
            .foregroundStyle(.primary)
          }
        }
      }
      .padding()
    }
    .navigationTitle(license.name)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showingFullLicense) {
      if let fullText = license.fullLicenseText {
        FullLicenseView(licenseName: license.name, fullText: fullText)
      }
    }
  }
}

/// 完全版ライセンス表示画面
struct FullLicenseView: View {
  let licenseName: String
  let fullText: String
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        Text(fullText)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .padding()
      }
      .navigationTitle(licenseName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("close", table: "Common")) {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  LicenseView()
}
