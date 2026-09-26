import UIKit

/// Draws the chart attached to a record share without an off-screen Swift Charts graph.
/// A single record and a zero-width date range are both valid here.
enum ShareChartRenderer {
  struct Point {
    let date: Date
    let capacity: Int
  }

  static func render(
    points: [Point], tint: UIColor, isDark: Bool, scale: CGFloat, locale: Locale
  ) -> UIImage? {
    guard !points.isEmpty else { return nil }
    let sorted = points.sorted { $0.date < $1.date }
    let rawStart = sorted[0].date.timeIntervalSince1970
    let rawEnd = sorted[sorted.count - 1].date.timeIntervalSince1970
    let start = rawStart == rawEnd ? rawStart - 43_200 : rawStart
    let end = rawStart == rawEnd ? rawEnd + 43_200 : rawEnd
    let capacities = sorted.map { Double($0.capacity) }
    guard let minimum = capacities.min(), let maximum = capacities.max() else { return nil }
    let padding = max(50, (maximum - minimum) * 0.1)
    let lower = max(0, minimum - padding)
    let upper = max(lower + 1, maximum + padding)

    let size = CGSize(width: 848, height: 528)
    let plot = CGRect(x: 92, y: 42, width: 714, height: 408)
    let format = UIGraphicsImageRendererFormat()
    format.scale = max(1, scale)
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let background = isDark ? UIColor.black : UIColor.white
    let labelColor = isDark ? UIColor.white : UIColor.black
    let gridColor = isDark ? UIColor.white.withAlphaComponent(0.25)
                           : UIColor.black.withAlphaComponent(0.18)
    let dateFormatter = DateFormatter()
    dateFormatter.locale = locale
    dateFormatter.dateStyle = .short

    return renderer.image { imageContext in
      let context = imageContext.cgContext
      background.setFill()
      context.fill(CGRect(origin: .zero, size: size))

      for index in 0...4 {
        let fraction = CGFloat(index) / 4
        let y = plot.minY + plot.height * fraction
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: plot.minX, y: y))
        context.addLine(to: CGPoint(x: plot.maxX, y: y))
        context.strokePath()

        let value = Int((upper - (upper - lower) * Double(fraction)).rounded())
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        ("\(value)mAh" as NSString).draw(
          in: CGRect(x: 4, y: y - 10, width: 78, height: 20),
          withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium),
                           .foregroundColor: labelColor, .paragraphStyle: paragraph])
      }

      for index in 0...2 {
        let fraction = Double(index) / 2
        let date = Date(timeIntervalSince1970: start + (end - start) * fraction)
        let text = dateFormatter.string(from: date) as NSString
        let textSize = text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        let x = plot.minX + plot.width * CGFloat(fraction) - textSize.width / 2
        text.draw(at: CGPoint(x: x, y: plot.maxY + 16),
                  withAttributes: [.font: UIFont.systemFont(ofSize: 14),
                                   .foregroundColor: labelColor])
      }

      let chartPoints = sorted.map { point in
        CGPoint(
          x: plot.minX + plot.width * CGFloat((point.date.timeIntervalSince1970 - start) / (end - start)),
          y: plot.maxY - plot.height * CGFloat((Double(point.capacity) - lower) / (upper - lower)))
      }
      context.setStrokeColor(tint.cgColor)
      context.setFillColor(tint.cgColor)
      context.setLineWidth(3)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      if let first = chartPoints.first {
        context.move(to: first)
        for point in chartPoints.dropFirst() { context.addLine(to: point) }
        context.strokePath()
      }
      for point in chartPoints {
        context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
      }
    }
  }
}
