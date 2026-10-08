#!/usr/bin/env swift
// Render localized App Store artwork around unmodified simulator screenshots.
import AppKit
import Foundation

struct Message {
    let headline: String
    let detail: String
    let category: String
}

let copy: [String: [String: [Message]]] = [
    "ja": [
        "iphone": [
            .init(headline: "電池の状態を、\nひと目で。", detail: "iPhoneもApple Watchも、毎日の記録をすっきり確認。", category: "ホーム"),
            .init(headline: "数字の裏側まで、\nちゃんと見える。", detail: "容量・充放電回数・診断結果を一画面に。", category: "ログ詳細"),
            .init(headline: "変化が見えると、\n安心できる。", detail: "容量とサイクルの推移をグラフで追跡。", category: "分析"),
            .init(headline: "使い方まで、\n自分好みに。", detail: "表示や同期を、必要に合わせて調整。", category: "設定")
        ],
        "ipad": [
            .init(headline: "複数端末の状態を、\nひと目に。", detail: "iPhone・iPad・Apple Watchをまとめて見渡す。", category: "ホーム"),
            .init(headline: "詳細データも、\n心地よく。", detail: "記録の数値を大画面で丁寧に確認。", category: "ログ詳細"),
            .init(headline: "長い時間の変化を、\n広い画面で。", detail: "推移を並べて、違いを見つけやすく。", category: "分析"),
            .init(headline: "管理も、\nすっきり。", detail: "必要な設定に迷わずアクセス。", category: "設定")
        ],
        "watch": [
            .init(headline: "手元で、\n電池を確認。", detail: "", category: "端末"),
            .init(headline: "記録を、\nさっと見る。", detail: "", category: "ログ"),
            .init(headline: "状態が、\nすぐわかる。", detail: "", category: "ヘルス"),
            .init(headline: "必要な数値を、\n手元に。", detail: "", category: "指標")
        ]
    ],
    "en-US": [
        "iphone": [
            .init(headline: "Battery health,\nat a glance.", detail: "See everyday records for iPhone and Apple Watch.", category: "HOME"),
            .init(headline: "Know what the\nnumbers mean.", detail: "Capacity, cycles and diagnostics in one clear view.", category: "DETAILS"),
            .init(headline: "See how your\nbattery changes.", detail: "Follow capacity and cycle trends over time.", category: "ANALYTICS"),
            .init(headline: "Make it work\nfor you.", detail: "Tune the display and sync to fit your needs.", category: "SETTINGS")
        ],
        "ipad": [
            .init(headline: "Every device,\none clear view.", detail: "See your iPhone, iPad and Apple Watch together.", category: "HOME"),
            .init(headline: "The details,\nbeautifully clear.", detail: "Take a closer look at every recorded value.", category: "DETAILS"),
            .init(headline: "More room to\nsee the trends.", detail: "Compare changes on a spacious display.", category: "ANALYTICS"),
            .init(headline: "Stay in control,\nsimply.", detail: "Find the settings you need with ease.", category: "SETTINGS")
        ],
        "watch": [
            .init(headline: "Battery health\non your wrist.", detail: "", category: "DEVICES"),
            .init(headline: "Your records,\none glance away.", detail: "", category: "LOGS"),
            .init(headline: "Check your\nbattery health.", detail: "", category: "HEALTH"),
            .init(headline: "Key numbers,\nclose at hand.", detail: "", category: "METRICS")
        ]
    ]
]

func usage() -> Never {
    fputs("Usage: swift scripts/compose-store-screenshots.swift RAW_SCREENSHOTS_DIR OUTPUT_DIR\n", stderr)
    exit(2)
}
guard CommandLine.arguments.count == 3 else { usage() }
let sourceRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputRoot = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let fileManager = FileManager.default
let expectedNames: [String: [String]] = [
    "iphone": ["01_home", "02_details", "03_analytics", "04_settings"],
    "ipad": ["01_home", "02_details", "03_analytics", "04_settings"],
    "duo_outer": ["01_home", "02_details", "03_analytics", "04_settings"],
    "duo_inner": ["01_home", "02_details", "03_analytics", "04_settings"],
    "watch": ["01_devices", "02_logs", "03_health", "04_metrics"]
]
let expectedSizes: [String: CGSize] = [
    "iphone": CGSize(width: 1320, height: 2868),
    "ipad": CGSize(width: 2064, height: 2752),
    "duo_outer": CGSize(width: 1398, height: 2034),
    "duo_inner": CGSize(width: 2007, height: 2853),
    "watch": CGSize(width: 416, height: 496)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rectFromTop(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, canvas: CGSize) -> NSRect {
    NSRect(x: x, y: canvas.height - y - height, width: width, height: height)
}

func drawText(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
              size: CGFloat, weight: NSFont.Weight, ink: NSColor, canvas: CGSize,
              lineSpacing: CGFloat = 0) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: ink, .paragraphStyle: paragraph
    ]
    (value as NSString).draw(in: rectFromTop(x, y, width, height, canvas: canvas), withAttributes: attributes)
}

func drawArtwork(source: NSImage, kind: String, message: Message, index: Int, destination: URL) throws {
    let canvas = expectedSizes[kind]!
    guard source.size == canvas else {
        throw NSError(domain: "ScreenshotDesign", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Unexpected \(kind) input size: \(source.size)"])
    }
    let isWatch = kind == "watch"
    let isDuo = kind.hasPrefix("duo_")
    let scale: CGFloat = isWatch ? 1 : (isDuo ? canvas.width / 1320 : (kind == "ipad" ? 1.55 : 1))
    let accent = color(0x46D477)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width),
                                  pixelsHigh: Int(canvas.height), bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "ScreenshotDesign", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot create graphics context"])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    let full = NSRect(origin: .zero, size: canvas)
    NSGradient(starting: color(0x111C1A), ending: color(0x080B10))!.draw(in: full, angle: 90)
    let glowSize = isWatch ? CGSize(width: 280, height: 250) : CGSize(width: canvas.width * 0.95, height: canvas.width * 0.8)
    let glowRect = NSRect(x: canvas.width * 0.52, y: canvas.height - glowSize.height * 1.1,
                          width: glowSize.width, height: glowSize.height)
    let glow = NSBezierPath(ovalIn: glowRect)
    NSGradient(starting: color(0x1A8655, alpha: isWatch ? 0.24 : 0.22), ending: color(0x1A8655, alpha: 0))!
        .draw(in: glow, relativeCenterPosition: .zero)

    let margin: CGFloat = isWatch ? 27 : (isDuo ? 70 * scale : (kind == "ipad" ? 134 : 94))
    let top: CGFloat = isWatch ? 21 : (isDuo ? 45 * scale : (kind == "ipad" ? 95 : 108))
    let dotSize: CGFloat = isWatch ? 7 : 13 * scale
    accent.setFill()
    NSBezierPath(ovalIn: rectFromTop(margin, top + (isWatch ? 6 : 15), dotSize, dotSize, canvas: canvas)).fill()
    drawText("MOCHILOG", x: margin + dotSize + (isWatch ? 8 : 18), y: top,
             width: canvas.width * 0.55, height: isWatch ? 26 : 50 * scale,
             size: isWatch ? 13 : 30 * scale, weight: .bold, ink: color(0xE4F3E9), canvas: canvas)
    let number = String(format: "%02d", index + 1)
    drawText(number, x: canvas.width - margin - (isWatch ? 34 : 78 * scale), y: top,
             width: isWatch ? 34 : 78 * scale, height: isWatch ? 25 : 45 * scale,
             size: isWatch ? 13 : 27 * scale, weight: .medium, ink: color(0x8AA69B), canvas: canvas)

    if isWatch {
        drawText(message.headline, x: margin, y: 55, width: canvas.width - 2 * margin,
                 height: 76, size: 28, weight: .bold, ink: color(0xF7FBF8), canvas: canvas, lineSpacing: 0)
        let bar = rectFromTop(margin, 132, 34, 3, canvas: canvas)
        accent.setFill()
        NSBezierPath(roundedRect: bar, xRadius: 2, yRadius: 2).fill()
    } else {
        let headlineY: CGFloat = isDuo ? 120 * scale : (kind == "ipad" ? 193 : 211)
        let headlineSize: CGFloat = isDuo ? 70 * scale : (kind == "ipad" ? 106 : 98)
        drawText(message.headline, x: margin, y: headlineY,
                 width: canvas.width - margin * 2,
                 height: isDuo ? 170 * scale : (kind == "ipad" ? 280 : 260),
                 size: headlineSize, weight: .bold, ink: color(0xF7FBF8), canvas: canvas,
                 lineSpacing: 7)
        let detailY: CGFloat = isDuo ? 300 * scale : (kind == "ipad" ? 486 : 475)
        drawText(message.detail, x: margin, y: detailY,
                 width: canvas.width - margin * 2, height: isDuo ? 70 * scale : (kind == "ipad" ? 94 : 135),
                 size: isDuo ? 27 * scale : (kind == "ipad" ? 40 : 39), weight: .regular,
                 ink: color(0xA8B9B0), canvas: canvas)
        let lineY: CGFloat = isDuo ? 390 * scale : (kind == "ipad" ? 617 : 650)
        color(0x4A6A5A, alpha: 0.75).setFill()
        NSBezierPath(roundedRect: rectFromTop(margin, lineY, canvas.width - margin * 2, 2, canvas: canvas),
                     xRadius: 1, yRadius: 1).fill()
        drawText(message.category, x: margin, y: lineY + 20,
                 width: canvas.width - margin * 2, height: 55,
                 size: kind == "ipad" ? 31 : 30, weight: .semibold,
                 ink: accent, canvas: canvas)
    }

    let screenshotY: CGFloat = isWatch ? 155 : (isDuo ? 470 * scale : (kind == "ipad" ? 720 : 765))
    let screenshotWidth = isDuo ? min(canvas.width - 120 * scale, (canvas.height - screenshotY - 70 * scale) * canvas.width / canvas.height) : canvas.width - 2 * (isWatch ? 20 : (kind == "ipad" ? 115 : 93))
    let screenshotX = (canvas.width - screenshotWidth) / 2
    let screenshotHeight = screenshotWidth * canvas.height / canvas.width
    let screenshotRect = rectFromTop(screenshotX, screenshotY, screenshotWidth, screenshotHeight, canvas: canvas)
    let radius: CGFloat = isWatch ? 40 : (kind == "ipad" ? 73 : 92)
    let bezel = NSBezierPath(roundedRect: screenshotRect.insetBy(dx: -3, dy: -3),
                             xRadius: radius + 3, yRadius: radius + 3)
    color(0x668575, alpha: isWatch ? 0.6 : 0.42).setStroke()
    bezel.lineWidth = isWatch ? 2 : 4
    bezel.stroke()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screenshotRect, xRadius: radius, yRadius: radius).addClip()
    source.draw(in: screenshotRect, from: NSRect(origin: .zero, size: canvas),
                operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
    NSGraphicsContext.restoreGraphicsState()

    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    // App Store images must not carry an alpha channel. AppKit drawing needs
    // RGBA; encode a separate RGB bitmap after painting the opaque background.
    let rgb = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width),
      pixelsHigh: Int(canvas.height), bitsPerSample: 8, samplesPerPixel: 3,
      hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let input = bitmap.bitmapData!, output = rgb.bitmapData!
    for y in 0..<Int(canvas.height) {
      for x in 0..<Int(canvas.width) {
        let src = y * bitmap.bytesPerRow + x * 4, dst = y * rgb.bytesPerRow + x * 3
        output[dst] = input[src]; output[dst + 1] = input[src + 1]; output[dst + 2] = input[src + 2]
      }
    }
    guard let data = rgb.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ScreenshotDesign", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot encode PNG"])
    }
    try data.write(to: destination, options: .atomic)
}

var count = 0
for locale in ["ja", "en-US"] {
    for kind in ["iphone", "ipad", "duo_outer", "duo_inner", "watch"] {
        let names = expectedNames[kind]!
        let messages = copy[locale]![kind.hasPrefix("duo_") ? "iphone" : kind]!
        for (index, screenName) in names.enumerated() {
            let filename = "\(kind)_\(screenName).png"
            let input = sourceRoot.appendingPathComponent(locale).appendingPathComponent(filename)
            guard fileManager.fileExists(atPath: input.path) else { continue }
            guard let screenshot = NSImage(contentsOf: input) else {
                throw NSError(domain: "ScreenshotDesign", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "Cannot read \(input.path)"])
            }
            let folder = outputRoot.appendingPathComponent(locale, isDirectory: true)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try drawArtwork(source: screenshot, kind: kind, message: messages[index],
                            index: index, destination: folder.appendingPathComponent(filename))
            count += 1
            print("Created \(locale)/\(filename)")
        }
    }
}
guard count > 0 else {
    fputs("No screenshots were found in \(sourceRoot.path)\n", stderr)
    exit(1)
}
print("\(count) App Store artwork files saved to \(outputRoot.path)")
