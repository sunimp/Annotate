//
//  SettingsPreviews.swift
//  Annotate
//
//  Created by Sun on 2026/11/26.
//

import AppKit
import SwiftUI

/// Pictures of annotations for the settings panes. `AnnotationRenderer` paints them, and
/// pixelate and blur go through `ScreenSampler`'s filters, so they match the overlay.
@MainActor
enum SettingsPreview {
    /// Size of the pictures in picker menus.
    static let menuIconSize = NSSize(width: 36, height: 20)

    /// The color annotations are drawn in right now.
    static var color: NSColor { CursorHighlightManager.shared.annotationColor }

    static func arrow(_ style: ArrowStyle, lineWidth: CGFloat, size: NSSize) -> NSImage {
        var document = OverlayDocument()
        // At most 3:1 so a wide tile still shows a slanted arrow, centered.
        let inset = max(4, lineWidth * 2)
        let height = size.height - inset * 2
        let width = min(size.width - inset * 2, height * 3)
        let minX = (size.width - width) / 2
        document.arrows = [
            Arrow(
                startPoint: NSPoint(x: minX, y: inset),
                endPoint: NSPoint(x: minX + width, y: inset + height),
                color: color, lineWidth: lineWidth, style: style),
        ]
        return render(document, size: size)
    }

    static func counter(_ style: CounterStyle, fontSize: CGFloat, size: NSSize) -> NSImage {
        var document = OverlayDocument()
        document.counterAnnotations = [
            CounterAnnotation(
                number: 1, position: NSPoint(x: size.width / 2, y: size.height / 2), color: color,
                fontSize: fontSize, style: style),
        ]
        return render(document, size: size)
    }

    /// A label centered in a picture as tall as the label needs.
    static func text(fontSize: CGFloat, hasBackground: Bool, width: CGFloat) -> NSImage {
        var label = TextAnnotation(
            text: "Aa 123", position: .zero, color: color, fontSize: fontSize, hasBackground: hasBackground)
        let labelSize = label.textSize()
        let size = NSSize(width: width, height: max(48, labelSize.height + 16))
        label.position = NSPoint(x: (size.width - labelSize.width) / 2, y: (size.height - labelSize.height) / 2)
        var document = OverlayDocument()
        document.textAnnotations = [label]
        return render(document, size: size)
    }

    /// A redaction over the end of a line of text on a white card, which stands in for the
    /// screen the filters would sample.
    static func redaction(
        _ style: RectangleStyle, size: NSSize, text: String = "Password: hunter2", fontSize: CGFloat = 18
    ) -> NSImage {
        let canvas = NSRect(origin: .zero, size: size)
        // Dark text, so the filtered blocks keep enough contrast to read as pixelated or blurred.
        var label = TextAnnotation(text: text, position: .zero, color: .black, fontSize: fontSize)
        let labelSize = label.textSize()
        label.position = NSPoint(x: (size.width - labelSize.width) / 2, y: (size.height - labelSize.height) / 2)
        label.creationTime = 1
        var document = OverlayDocument()
        // Pale color bands, so the filters have something to smear besides thin glyphs.
        let bands: [NSColor] = [.systemBlue, .systemPink, .systemOrange, .systemGreen, .systemPurple]
        let bandWidth = size.width / CGFloat(bands.count)
        document.rectangles = [
            Rectangle(
                startPoint: canvas.origin, endPoint: NSPoint(x: canvas.maxX, y: canvas.maxY), color: .white,
                lineWidth: 0, creationTime: 0, style: .filled),
        ] + bands.enumerated().map { index, band in
            Rectangle(
                startPoint: NSPoint(x: CGFloat(index) * bandWidth, y: 0),
                endPoint: NSPoint(x: CGFloat(index + 1) * bandWidth, y: size.height),
                color: band.withAlphaComponent(0.35), lineWidth: 0, creationTime: 0, style: .filled)
        }
        document.textAnnotations = [label]

        let cover = NSRect(
            x: label.position.x + labelSize.width * 0.55, y: label.position.y,
            width: labelSize.width * 0.45, height: labelSize.height
        ).insetBy(dx: -2, dy: -2).integral.intersection(canvas)
        let bounds = cover
        var rectangle = Rectangle(
            startPoint: bounds.origin, endPoint: NSPoint(x: bounds.maxX, y: bounds.maxY), color: color,
            lineWidth: 1, creationTime: 2, style: style)
        // The text stands in for the screen the filters would sample.
        if rectangle.needsSample, let screen = render(document, size: size).cgImage(
            forProposedRect: nil, context: nil, hints: nil),
            let result = ScreenSampler.makeSample(
                from: DisplaySnapshot(image: screen, displayFrame: canvas),
                screenRect: bounds, style: style)
        {
            rectangle.sample = RedactionSample(
                image: result.image, bounds: result.screenRect, key: RedactionSampleKey(rectangle))
        }
        document.rectangles.append(rectangle)
        return render(document, size: size)
    }

    static func stroke(lineWidth: CGFloat, color: NSColor, size: NSSize) -> NSImage {
        var document = OverlayDocument()
        document.lines = [
            Line(
                startPoint: NSPoint(x: 12, y: size.height / 2),
                endPoint: NSPoint(x: size.width - 12, y: size.height / 2), color: color, lineWidth: lineWidth),
        ]
        return render(document, size: size)
    }

    /// Paints `document` into a 2x bitmap `size` points large.
    static func render(_ document: OverlayDocument, size: NSSize) -> NSImage {
        let scale: CGFloat = 2
        let image = NSImage(size: size)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return image }
        context.cgContext.scaleBy(x: scale, y: scale)
        AnnotationRenderer(
            document: document, live: nil, board: .hidden, fade: .fullStrength, now: 0,
            canvas: NSRect(origin: .zero, size: size)
        ).draw(in: context.cgContext)
        context.flushGraphics()
        rep.size = size
        image.addRepresentation(rep)
        return image
    }
}

/// A preview picture in a rounded tile, as wide as the form row.
struct SettingsPreviewTile: View {
    let image: NSImage

    var body: some View {
        Image(nsImage: image)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}
