import AppKit

/// What sits left of the number in the menu bar, picked in Settings › General › Menu Bar.
enum MenuBarIcon: String, CaseIterable, Codable {
    case quote, graduationCap, book, chart, sparkles, star, classic, none, custom

    var title: String {
        switch self {
        case .quote: return "Quotation mark"
        case .graduationCap: return "Graduation cap"
        case .book: return "Book"
        case .chart: return "Rising chart"
        case .sparkles: return "Sparkles"
        case .star: return "Star"
        case .classic: return "Classic"
        case .none: return "Number only"
        case .custom: return "Your own image"
        }
    }

    /// The SF Symbol for the built-in choices. Classic keeps its old calendar for this year's count.
    func symbolName(currentYear: Bool = false) -> String? {
        switch self {
        case .quote: return "quote.opening"
        case .graduationCap: return "graduationcap.fill"
        case .book: return "text.book.closed.fill"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .sparkles: return "sparkles"
        case .star: return "star.fill"
        case .classic: return currentYear ? "calendar.circle.fill" : "book.circle.fill"
        case .none, .custom: return nil
        }
    }
}

/// The user's own menu bar picture, saved as a small PNG next to the data files.
@MainActor enum CustomMenuBarIcon {
    /// Menu bar height in points; the PNG is saved at twice that for Retina screens.
    static let height: CGFloat = 18
    private static var cached: NSImage?

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CiteBar/menu-bar-icon.png")
    }

    /// Fits a picked file to the menu bar and saves it. Throws for files that aren't images.
    static func save(from source: URL) throws {
        guard let image = NSImage(contentsOf: source), image.size.width > 0, image.size.height > 0,
              let fileURL else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let png = try fitted(image)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: fileURL, options: .atomic)
        cached = nil
    }

    static func image() -> NSImage? {
        if let cached { return cached }
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let bitmap = NSBitmapImageRep(data: data) else { return nil }
        let image = NSImage(size: NSSize(width: CGFloat(bitmap.pixelsWide) / 2, height: CGFloat(bitmap.pixelsHigh) / 2))
        image.addRepresentation(bitmap)
        image.isTemplate = shouldTint(bitmap)
        cached = image
        return image
    }

    /// The image drawn into a canvas 18 pt tall and at most twice as wide, keeping its proportions.
    private static func fitted(_ image: NSImage) throws -> Data {
        let pixelHeight = Int(height * 2)
        let aspect = min(max(image.size.width / image.size.height, 0.5), 2)
        let pixelWidth = Int((CGFloat(pixelHeight) * aspect).rounded())
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { throw CocoaError(.fileWriteUnknown) }

        let canvas = NSSize(width: pixelWidth, height: pixelHeight)
        let fit = min(canvas.width / image.size.width, canvas.height / image.size.height)
        let drawn = NSSize(width: image.size.width * fit, height: image.size.height * fit)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: (canvas.width - drawn.width) / 2, y: (canvas.height - drawn.height) / 2,
                              width: drawn.width, height: drawn.height))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return png
    }

    /// A gray shape on a transparent background, such as a logo glyph, is drawn like the system
    /// icons so it stays visible in a light or dark menu bar. Colorful or opaque pictures keep
    /// their own colors, since tinting would flatten them into a solid shape.
    nonisolated static func shouldTint(_ bitmap: NSBitmapImageRep) -> Bool {
        var transparent = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.alphaComponent < 0.1 {
                    transparent += 1
                    continue
                }
                let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                if (channels.max() ?? 0) - (channels.min() ?? 0) > 0.15 {
                    return false
                }
            }
        }
        return transparent * 10 >= bitmap.pixelsWide * bitmap.pixelsHigh
    }
}
