#!/usr/bin/env swift  // Compose App Store creative assets from the app icon and actual, localized UI.
import AppKit
import Foundation
import ImageIO

struct CreativeCopy {
  let header: String
  let headline: String
  let detail: String
}

let messages = [
  "ja": CreativeCopy(
    header: "電池の変化を、記録に。", headline: "電池の変化を、\nひと目で。", detail: "容量と充放電回数を、見える記録に。"),
  "en-US": CreativeCopy(
    header: "Know your battery. Over time.", headline: "Battery health.\nOver time.",
    detail: "See capacity and cycle trends."),
]

guard CommandLine.arguments.count == 3 else {
  fputs("Usage: swift scripts/compose-store-creative.swift RAW_IPHONE_DIR OUTPUT_DIR\n", stderr)
  exit(2)
}
let inputRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputRoot = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  .deletingLastPathComponent()
let iconURL = repository.appendingPathComponent(
  "icon/Icon Exports/Icon-iOS-Default-1024x1024@1x.png")
guard let icon = NSImage(contentsOf: iconURL) else { fatalError("Missing app icon") }

func ink(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 255) / 255,
    green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ canvas: CGSize)
  -> NSRect
{
  NSRect(x: x, y: canvas.height - y - height, width: width, height: height)
}

func text(
  _ value: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight,
  color: NSColor, spacing: CGFloat = 0
) {
  let style = NSMutableParagraphStyle()
  style.lineBreakMode = .byWordWrapping
  style.lineSpacing = spacing
  (value as NSString).draw(
    in: rect,
    withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
      .paragraphStyle: style,
    ])
}

func glow(_ center: NSPoint, radius: CGFloat, color: NSColor) {
  let gradient = NSGradient(starting: color, ending: color.withAlphaComponent(0))!
  gradient.draw(
    fromCenter: center, radius: 0, toCenter: center, radius: radius,
    options: .drawsBeforeStartingLocation)
}

func background(_ size: CGSize) {
  let bounds = NSRect(origin: .zero, size: size)
  NSGradient(colors: [ink(0x07120E), ink(0x10271C), ink(0x06100D)])!.draw(in: bounds, angle: 18)
  glow(
    NSPoint(x: size.width * 0.63, y: size.height * 0.53), radius: 1450,
    color: ink(0x267D4B, 0.21))
  glow(
    NSPoint(x: size.width * 0.32, y: size.height * 0.47), radius: 820,
    color: ink(0x4854B9, 0.19))

  // Unlabelled, decorative contours echo the app's capacity charts.
  for (index, color) in [ink(0x46D477, 0.13), ink(0x66B9FF, 0.08), ink(0x46D477, 0.05)]
    .enumerated()
  {
    let path = NSBezierPath()
    let y = size.height * 0.33 + CGFloat(index) * 66
    path.move(to: NSPoint(x: -180, y: y))
    path.curve(
      to: NSPoint(x: size.width + 180, y: y + size.height * 0.19),
      controlPoint1: NSPoint(x: size.width * 0.36, y: y + size.height * 0.38),
      controlPoint2: NSPoint(x: size.width * 0.72, y: y - size.height * 0.25))
    color.setStroke()
    path.lineWidth = index == 0 ? 4 : 2
    path.stroke()
  }
  for radius: CGFloat in [850, 1100, 1430] {
    let ring = NSBezierPath(
      ovalIn: NSRect(
        x: size.width * 0.58 - radius, y: size.height * 0.52 - radius,
        width: radius * 2, height: radius * 2))
    ink(0x89C8A6, 0.045).setStroke()
    ring.lineWidth = 2
    ring.stroke()
  }
}

func drawIcon(_ rect: NSRect) {
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = ink(0x000000, 0.35)
  shadow.shadowBlurRadius = 58
  shadow.shadowOffset = NSSize(width: 0, height: -20)
  shadow.set()
  icon.draw(in: rect)
  NSGraphicsContext.restoreGraphicsState()
}

func analyticsImage(_ file: URL) throws -> NSImage {
  guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
    image.width == 1320, image.height == 2868
  else {
    throw NSError(
      domain: "StoreCreative", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Expected a current 1320×2868 analytics screenshot"])
  }
  // Keep the complete actual screen; no UI, labels or values are redrawn.
  return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
}

func render(kind: String, locale: String, copy: CreativeCopy, analytics: NSImage) throws {
  let canvas = CGSize(width: 3840, height: kind == "header" ? 1646 : 2560)
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  graphics.imageInterpolation = .high
  background(canvas)
  if kind == "header" {
    // Official 3840×1646 template: centered art-safe area (1097,493,1646,661).
    drawIcon(box(1180, 638, 360, 360, canvas))
    text(
      "MochiLog", box(1620, 661, 1040, 240, canvas), size: 178, weight: .bold,
      color: ink(0xF7FBF8))
    text(
      copy.header, box(1627, 900, 1040, 92, canvas), size: locale == "ja" ? 66 : 59,
      weight: .medium, color: ink(0xB6CDBF))
    ink(0x46D477).setFill()
    NSBezierPath(
      roundedRect: box(1632, 1030, 100, 7, canvas), xRadius: 3.5, yRadius: 3.5
    ).fill()
  } else {
    // Official 3840×2560 template: centered art-safe area (836,765,2168,1030).
    drawIcon(box(956, 890, 122, 122, canvas))
    text(
      "MochiLog", box(1115, 908, 820, 110, canvas), size: 77, weight: .semibold,
      color: ink(0xE6F1EA))
    text(
      copy.headline, box(950, 1087, 1060, 400, canvas), size: locale == "ja" ? 125 : 128,
      weight: .bold, color: ink(0xF7FBF8), spacing: 12)
    text(
      copy.detail, box(956, 1493, 1020, 150, canvas), size: locale == "ja" ? 48 : 53,
      weight: .medium, color: ink(0xB6CDBF))
    // The first chart sits inside the art-safe area, while the full screen
    // provides context in placements that expose more of the canvas.
    let card = box(2040, 350, 900, 900 * analytics.size.height / analytics.size.width, canvas)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = ink(0x000000, 0.46)
    shadow.shadowBlurRadius = 80
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    ink(0x1C1C1E).setFill()
    NSBezierPath(roundedRect: card, xRadius: 78, yRadius: 78).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: card, xRadius: 78, yRadius: 78).addClip()
    analytics.draw(in: card)
    NSGraphicsContext.restoreGraphicsState()
    ink(0x9DCEB1, 0.26).setStroke()
    let border = NSBezierPath(roundedRect: card, xRadius: 78, yRadius: 78)
    border.lineWidth = 4
    border.stroke()
  }
  graphics.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()

  // Drawing uses RGBA; published creative assets must be opaque RGB PNGs.
  let rgb = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  for y in 0..<Int(canvas.height) {
    for x in 0..<Int(canvas.width) {
      let source = y * bitmap.bytesPerRow + x * 4
      let destination = y * rgb.bytesPerRow + x * 3
      for channel in 0..<3 {
        rgb.bitmapData![destination + channel] = bitmap.bitmapData![source + channel]
      }
    }
  }
  guard let data = rgb.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode creative PNG")
  }
  let folder = outputRoot.appendingPathComponent(locale, isDirectory: true)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  try data.write(to: folder.appendingPathComponent("\(kind).png"), options: .atomic)
  print("Created \(locale)/\(kind).png — \(Int(canvas.width))×\(Int(canvas.height)), RGB")
}

for locale in ["ja", "en-US"] {
  let analytics = try analyticsImage(
    inputRoot.appendingPathComponent(locale).appendingPathComponent("iphone_03_analytics.png"))
  for kind in ["header", "search"] {
    try render(kind: kind, locale: locale, copy: messages[locale]!, analytics: analytics)
  }
}
