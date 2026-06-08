#!/usr/bin/env swift
import AppKit
import CoreText

func makeIcon(px: Int) -> Data {
    let s = CGFloat(px)

    let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)!
    let cg = NSGraphicsContext.current!.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    // ── Background: deep forest green gradient ──────────────────────────────
    let topGreen = CGColor(red: 0.13, green: 0.36, blue: 0.23, alpha: 1)
    let botGreen = CGColor(red: 0.07, green: 0.19, blue: 0.12, alpha: 1)
    let bgGrad = CGGradient(colorsSpace: cs,
                            colors: [topGreen, botGreen] as CFArray,
                            locations: [0, 1])!
    cg.drawLinearGradient(bgGrad,
                          start: CGPoint(x: s / 2, y: s),
                          end:   CGPoint(x: s / 2, y: 0),
                          options: [])

    // ── Vignette ────────────────────────────────────────────────────────────
    let clear = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    let dark  = CGColor(red: 0, green: 0, blue: 0, alpha: 0.28)
    let vig = CGGradient(colorsSpace: cs,
                         colors: [clear, dark] as CFArray,
                         locations: [0.42, 1.0])!
    cg.drawRadialGradient(vig,
                          startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
                          endCenter:   CGPoint(x: s / 2, y: s / 2), endRadius: s * 0.72,
                          options: CGGradientDrawingOptions(rawValue: 0))

    // ── "W" in cream Georgia Bold ────────────────────────────────────────────
    let fontSize = s * 0.60
    let fontRef  = CTFontCreateWithName("Georgia-Bold" as CFString, fontSize, nil)
    let cream    = NSColor(red: 0.96, green: 0.93, blue: 0.87, alpha: 1).cgColor

    let attrStr = NSAttributedString(string: "W", attributes: [
        kCTFontAttributeName            as NSAttributedString.Key: fontRef,
        kCTForegroundColorAttributeName as NSAttributedString.Key: cream
    ])
    let line   = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    // Center glyph; nudge up slightly so gold line reads as part of the composition
    let tx = (s - bounds.width)  / 2 - bounds.origin.x
    let ty = (s - bounds.height) / 2 - bounds.origin.y + s * 0.04

    cg.textPosition = CGPoint(x: tx, y: ty)
    CTLineDraw(line, cg)

    // ── Gold accent line ─────────────────────────────────────────────────────
    let lineH = max(1.5, s * 0.022)
    let lineY = ty - s * 0.060
    let lineX = s * 0.20
    let lineW = s * 0.60
    cg.setFillColor(CGColor(red: 0.91, green: 0.74, blue: 0.38, alpha: 1))
    cg.fill(CGRect(x: lineX, y: lineY, width: lineW, height: lineH))

    return bmp.representation(using: .png, properties: [:])!
}

// ── Write iconset ────────────────────────────────────────────────────────────
let dir = "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in specs {
    try! makeIcon(px: px).write(to: URL(fileURLWithPath: dir + "/" + name))
    print("✓  \(name) @ \(px)px")
}
print("Done — run: iconutil -c icns AppIcon.iconset")
